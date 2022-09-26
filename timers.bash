#!/bin/bash
# Handle timers via mqtt from Rhasspy (work in progress)
# Uses labeled timers:
# - labels can be any single word noun
# - labels can be the timer duration (in minutes)
# - special named timers can have pre-set durations
# - time can be added to a timer via its label
# - the special timer labeled "that" refers to the most recent timer

# rhasspy rules:
#  [Timer]
#  timer_duration=(1..59){minutes} [and a half{seconds:30}] minute)
#  timer_label=($nouns){label}
#  timer_named=(pizza | egg | bread | englishmuffin | crumpet | cookie | yogurt){label}
#  timer_delta=(30 seconds | 1 minute | 2..30 minutes){delta}
#  timer_ref=(the <timer_label>|the <timer_duration>|that)
#  
#  set (the|a) <timer_duration> timer (named|called) <timer_label> (:){action:set}
#  set (the|a) <timer_label> timer for <timer_duration> (:){action:set}
#  set (the|a) (<timer_named>|<timer_duration>) timer (:){action:set}
#  add <timer_delta> to <timer_ref> timer(:){action:add}
#  cancel <timer_ref> timer (:){action:cancel}
#  cancel all timers (:){action:cancel_all}
#  
#  what are the timers (:){action:queryall}
#  help [with] timers (:){action:help}
# Keywords (name=value)
#  action=set|add|cancel|cance_all|query_all|help - primary timer action
#  minutes=1..50   - timer duration in minutes
#  seconds=        - add this seconds to timer
#  label=<noun>    - label for the timer (if supplied)
# Theory of operation
#  "Now" contains the current time (in unix seconds)
#  Timers[label]=duration started PID [added]
#  - label: either the timer name, or its duration in seconds
#  - started: the unix seconds the timer was started
#  - duration: original timer duration, in seconds
#  - PID:  The process id of the "sleep" process that will trigger the alarm
#  - added:  Any additional time added to the timer (in seconds)
#    "added" in the Timer[] must match "added" in the alarm for it to fire
#  - All commands are read from a queue (a fifo named "timer_fifo"), they consist of json from the 
#   recogniser, and alarms, set up when a timer is created
#  - All commands consist of lines of the form "name=value", terminated by the line: command=<something>
# Configuration parameters
MQTT_HOST=localhost          # host of mqtt server
MQTT_TOPIC=Timer             # topic to read voice commands from
ALARM_SOUND=fanfare.wav      # what to play when the alarm sounds
FIFO=timer_fifo

declare -A Args   # Command arguments
declare -A Timers # Current timers. Timer[label]="duration_sec start_sec PID [added]"
Last=""           # label of most recently set or expired timer
Now=0             # Current Unix time

LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
SOUND_DIR="$LIB_DIR/sounds"
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

# These are the named timers (times in seconds)
declare -A NamedTimers=(
  [pizza]=330
  [egg]=660
  [bread]=1200
  [englishmuffin]=330
  [crumpet]=330
  [yogurt]=14400
  [chocolate-chip-cookie]=660
  [swap-the-cookie-trays]=330
)

# Permits interactice debugging via source $0
function reset {
  unset Timers
  unset Last
  declare -Ag Timers
}

# get the time left, in seconds, for a labeled timer
function sec_left() {
  local seconds started pid added result
  local timer="${1}" 
  read -r seconds started pid added <<< "${Timers[$timer]}"
  result=$(sec_left_helper "$seconds" "$started" "$added")
  echo "$result"
}

# compute time left on timer
function sec_left_helper() {
  local sec="$1" start="$2" added="${3:-0}"
  echo $((start + sec + added - Now))
}

# Text to speak the time left on a timer.
function say_time_left {
  local timer="${1}" 
  say_time "$(sec_left "$timer")"
}

# Text to speak the provided time (in seconds)
function say_time {
  local seconds="${1}" 
  (( seconds < 0 )) && seconds=$((-seconds))
  local min="$((seconds / 60))"
  local sec="$((seconds % 60))"
  (( min > 0 )) && say_number "$min" minute ", "
  (( sec > 0 )) && say_number $sec second
}

function do_sleep() {
  sleep "${1}"
}

# start a timer given "timer" and "duration", in seconds"
function start_timer() {
  local timer="$1" seconds="$2" added="${3:-0}"
  local sleep_for=${4:-$seconds}
  ( echo $BASHPID>pids;
    do_sleep "$sleep_for";
    enqueue "$FIFO" "label=$1" "added=$added" "action=alarm"
  )&
  read -r pid < pids
  Timers["$timer"]="$seconds $Now $pid $added"
  Last="$timer"
  debug "$timer: $(declare -p Timers)"
}

# Start a timer, or call special handler, if available.
# use s named timer, if no duration specified.
function set_timer {
  local timer="${1:-test}" sec="$2"
  (( sec > 0 )) || sec=${NamedTimers[$timer]:-30}
  # process as a special case, if defined
  [[ $(type -t "special_$timer") == "function" ]] && { "special_$timer" "$timer" "$sec"; return; }
  start_timer "$timer" "$sec"
  speak "setting the $(say_timer "$timer") timer"
}

# Sample special function timer
function special_cookie {
  debug "$*"
  enqueue "$FIFO" "action=set" "label=swap-the-cookie-trays"
  enqueue "$FIFO" "action=set" "label=chocolate-chip-cookie"
}

# Must be a valid running timer
function cancel_timer {
  local timer=${1:-none}
  local seconds start pid added
  read -r seconds start pid added <<< "${Timers[$timer]}"
  speak "Cancelling the, $(say_timer "$timer") timer with $(say_time_left "$timer") left."
  unset_timer "$timer"
  Last="$timer"
  kill "$pid"
  return 0
}

# say a timer name and/or duration
function say_timer() {
  local timer="$1"
  local seconds x added=0
  [[ "$timer" =~ ^[0-9]+$ ]] && { say_duration "$timer"; return; }
  has_timer "$timer" && { read -r seconds x x added <<<  "${Timers["$timer"]}"; say_duration "$seconds" ;}
  (( added > 0 )) && echo -n ", with $(say_duration "$added") added, "
  echo -n " $timer"
}

# Say a timer duration, given a number of seconds
function say_duration() {
  local seconds="$1"
  (( seconds < 60 )) && { echo -n "$seconds second " ; return; }
  local min=$(( seconds / 60 ))
  local sec=$(( seconds % 60 ))
  (( sec == 30 )) && { echo -n "$min and a half minute " ; return; }
  (( sec == 0 )) && { echo -n "$min minute " ; return; }
  echo -n "$min minute, $sec second "
}

function say_running() {
  local timer="${1}"
  speak "the $(say_timer "$timer") timer is already running with $(say_time_left "$timer") left."
}

function say_none() {
  local timer="${1}"
  speak "There is no $(say_timer "$timer") timer to cancel."
}

function say_missing {
  speak "Sorry, I don't know which timer to cancel."
}

# Current time, in seconds
function get_now {
  printf -v Now "%(%s)T"
}

# run a command based on Args[action]

# Process the alarm
# args: timer, added_seconds
function do_alarm() {
  local timer="$1" add="${2:-0}"
  local seconds started pid added
  read -r seconds started pid added <<<  "${Timers[$timer]}"
  (( added == add )) || { debug "ignoring alarm"; unset_timer "$timer"; return; }
  play_wav $ALARM_SOUND
  speak "the $(say_timer "$timer") timer just ended."
  speak "you have $(say_number "$(count_running)" timer) remaining."
  Last="$timer"
}
function do_set() {
  local sec="$1" timer="${2:-$1}"
  has_timer "$timer"  && (( $(sec_left "$timer") < 0 )) && unset_timer "$timer"
  has_timer "$timer"  && say_running "$timer" || set_timer "$timer" "$sec"
}

function do_cancel() {
  local timer=${1}
  [[ $timer == "that" ]] && timer="$Last"
  is_running "$timer" && cancel_timer "$timer" || say_none "$timer"
  speak "you have $(say_number "$(count_running)" timer) remaining."
}

function do_help() {
  speak "you can say:"
  speak "  set the seventeen minute timer."
  speak "  set the pizza timer."
  speak "  set a two minute timer named elephant"
  speak "  add 2 and a half minutes to the pizza timer"
  speak "  cancel that timer."
  speak "  cancel the seventeen minute timer."
  speak "  what are the timers."
}

function do_cancel_all() {
  speak "cancelling $(say_number "$(count_running)" timer)."
  for timer in "${!Timers[@]}"; do
    is_running "$timer" && cancel_timer "$timer" || unset_timer "$timer"
  done
}


# describe all timers, removing all expired timers
function do_query_all() {
  local s_running s_expired
  local running=0 total=0
  local seconds started pid added
  for timer in "${!Timers[@]}"; do
    read -r seconds started pid added <<< "${Timers[$timer]}"
    left=$(sec_left_helper "$seconds" "$started" "$added")
    (( left + seconds < 0 )) && { unset_timer "$timer" ; continue ; }
    (( total=total + 1 ))
    local say=" The, $(say_timer "$timer") timer "
    (( left == 0 )) && s_expired+="$say has just expired."
    (( left > 0 )) && { s_running+="$say has $(say_time_left "$timer") left." ; ((running=running + 1)) ; }
    (( left < 0  )) && { s_expired+="$say expired $(say_time_left "$timer") ago." ; unset_timer "$timer" ; }
  done
  local expired=$((total - running))
  ((total == 0)) && { speak "There are no timers running." ; return ; }
  (( expired == 0 && running == 1)) && { speak "$s_running" ; return ; }
  (( expired == 0 )) && { speak "There are $running timers. $s_running" ; return ; }
  (( expired == 1 && running == 0)) && { speak "$s_expired" ; return ; }
  speak "$(say_number "$running" "active timer") $s_running $s_expired"
}

# convert time added to a timer into seconds
function delta_to_sec() {
  local val unit
  read -r val unit <<< "$1"
  [[ $unit == mi* ]] && val=$((val * 60))
  echo "$val"
}

# Add specified seconds to named timer
function add_to() {
  local timer="$1" delta_sec="$2" say_delta="$3"
  local left seconds started pid added note=""
  left=$(sec_left "$timer")

  (( left < 0 )) && note+="recently expired"
  (( left + delta_sec < 0 )) && {
    speak "The $(say_timer "$timer") expired too long ago, create a new timer"
    unset_timer "$timer"
    return
  }
  read -r seconds started pid added <<< "${Timers[$timer]}"
  added=$((added + delta_sec))
  kill "$pid"
  local sleep_for=$((left + delta_sec))
  speak "adding $say_delta to the $note $(say_timer "$timer") timer, now with $(say_time "$sleep_for") left"
  start_timer "$timer" "$seconds" "$added" "$sleep_for"
}

function do_delta() {
  local timer="${1:-$2}" delta="$3" sec="$(delta_to_sec "$delta")"
  has_timer "$timer" && add_to "$timer" "$sec" "$delta" || \
  speak "There is no $(say_timer "$timer") timer to add $delta to."
}

function do_command {
  local command="${Args[action]}"
  local timer="${Args[label]}"
  local minutes="${Args[minutes]:-0}"
  local seconds="${Args[seconds]:-0}"
  local delta="${Args[delta]}"
  [[ $timer == "that" ]] && timer="$Last"
  get_now
  case $command in 
    alarm)      do_alarm "$timer" "${Args[added]}" ;;
    set)        do_set "$((minutes * 60 + seconds))" "$timer";;
    cancel)     do_cancel "$timer" ;;
    help)       do_help ;;
    cancel_all) do_cancel_all ;;
    queryall)   do_query_all ;;
    add)        do_delta "$timer" "$((minutes * 60 + seconds))" "$delta" ;;
    reload)     speak "reloading"; . ./timers.bash;;
    *) speak "command, $command, not understood" ;;
  esac
}

# convenience timer functions
function has_timer() {
  local timer="$1"
  [[ -v "Timers[$timer]" ]]
}

function is_running() {
  local timer="$1"
  has_timer "$timer" && (( $(sec_left "$timer") > 0 ))
}

# count running timers
function count_running() {
  local count=0
  local seconds started pid added
  for timer in "${!Timers[@]}"; do
    is_running "$timer" && (( count=count+1 ))
  done
  debug "$count / ${#Timers[@]}"
  echo "$count"
}

function unset_timer() {
  local timer="$1"
  unset Timers["$timer"]
  [[ $timer == "$Last" ]] && Last=""
  debug "$timer"
  return 0
}


function clean() {
  rm -f pids
}

function main() {
	debug "Starting timers"
  rm -f pids;mkfifo pids # to pass subshell PID
  get_now
	queue_main "$MQTT_TOPIC" do_command $FIFO clean
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
echo "run 'main' to start"
