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
#  - All commands are read from a queue (a fifo named "fifo"), they consist of json from the 
#   recogniser, and alarms, set up when a timer is created
#  - All commands consist of lines of the form "name=value", terminated by the line: command=<something>
# Configuration parameters
HOST=localhost          #   host of mqtt server
SOUND_DIR=sounds        # directory to find sound files in.
ALARM_SOUND=fanfare.wav # what to play when the alarm sounds
cd /home/suhler/assistant || exit

declare -A Args   # Command arguments
declare -A Timers # Current timers. Timer[label]="duration_sec start_sec PID [added]"
Last=""           # label of most recently set or expired timer
Now=0             # Current Unix time

# print args preceded by function name
function debug {
  echo "$BASH_SOURCE: ${FUNCNAME[1]}: $*" > /dev/stderr
}

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

# Listen for timer events from mqtt
function watch {
  local host="$1" intent="$2"
  mosquitto_sub -h "$host" -t "hermes/intent/$intent" 
}

# Extract slots from a timer event as name=value pairs.
#   add a dummy slot "command=xxx" at the end to trigger the action.
function extract {
   jq --unbuffered -r \
   '.slots|map({(.slotName):.value.value})|. += [{"command":"timer"}]|add|to_entries[]|join("=")' 
}

# Play a sound file via MQTT
function play_wav() {
  local file=${1:-boing.wav}
  local id=${2:-dflt}
  mosquitto_pub -h $HOST \
    -t "hermes/audioServer/default/playBytes/$id"\
    -f "$SOUND_DIR/$file"
}

# Text to speech (must succeed)
function speak {
 local text="${1:-hello}"
 debug "$text"
 mosquitto_pub -h $HOST -t hermes/tts/say -m '{"text":"'"$text"'"}'
 return 0
}

# get the time left, in seconds, for a labeled timer
function sec_left() {
  local seconds started pid added result
  local label="${1}" 
  read -r seconds started pid added <<< "${Timers[$label]}"
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
  local label="${1}" 
  say_time "$(sec_left "$label")"
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

# put a command onto our Fifo
function enqueue() {
  local cmd=""
  for i in "$@" ; do
    cmd+="$i"
    cmd+='\n'
  done
  cmd+='command=done'
  echo -e $cmd > fifo
}

# start a timer given "label" and "duration", in seconds"
function start_timer() {
  local label="$1" seconds="$2" added="${3:-0}"
  local sleep_for=${4:-$seconds}
  ( echo $BASHPID>pids;
    do_sleep "$sleep_for";
    enqueue "label=$1" "added=$added" "action=alarm"
  )&
  read -r pid < pids
  Timers["$label"]="$seconds $Now $pid $added"
  Last="$label"
  debug "$label: $(declare -p Timers)"
}

# Start a timer, or call special handler, if available.
# use s named timer, if no duration specified.
function set_timer {
  local label="${1:-test}" sec="$2"
  (( sec > 0 )) || sec=${NamedTimers[$label]:-30}
  # process as a special case, if defined
  [[ $(type -t "special_$label") == "function" ]] && { "special_$label" "$label" "$sec"; return; }
  start_timer "$label" "$sec"
  speak "setting the $(say_timer "$label") timer"
}

# Sample special function timer
function special_cookie {
  debug "$*"
  enqueue "action=set" "label=swap-the-cookie-trays"
  enqueue "action=set" "label=chocolate-chip-cookie"
}

# Must be a valid timer
function cancel_timer {
  local label=${1:-none}
  local seconds start pid added
  read -r seconds start pid added <<< "${Timers[$label]}"
  speak "Cancelling the, $(say_timer "$label") timer with $(say_time_left "$label") left."
  unset_timer "$label"
  Last="$label"
  kill "$pid"
  return 0
}

# Say a number with proper noun suffix.
function say_number() { 
  local number="$1" noun="$2" at_end="$3"
  case "$number" in
    0) echo -n "no ${noun}s";;
    1) echo -n "one $noun";;
    *) echo -n "$number ${noun}s";;
  esac
  echo -n "$at_end"
}

# say a timer name and/or duration
function say_timer() {
  local label="$1"
  local seconds x added=0
  [[ "$label" =~ ^[0-9]+$ ]] && { say_duration "$label"; return; }
  has_timer "$label" && { read -r seconds x x added <<<  "${Timers["$label"]}"; say_duration "$seconds" ;}
  (( added > 0 )) && echo -n ", with $(say_duration "$added") added, "
  echo -n " $label"
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
  local label="${1}"
  speak "the $(say_timer "$label") timer is already running with $(say_time_left "$label") left."
}

function say_none() {
  local label="${1}"
  speak "There is no $(say_timer "$label") timer to cancel."
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
# args: label, added_seconds
function do_alarm() {
  label="$1" add="${2:-0}"
  local seconds started pid added
  read -r seconds started pid added <<<  "${Timers[$label]}"
  (( added == add )) || { debug "ignoring alarm"; unset_timer "$label"; return; }
  debug "$label: ${Timers[$label]}"
  play_wav $ALARM_SOUND
  speak "the $(say_timer "$label") timer just ended."
  speak "you have $(say_number "$(( ${#Timers[@]} - 1 ))" timer) remaining."
  Last="$label"
}

function has_timer() {
  local label="$1"
  [[ -v "Timers[$label]" ]]
}

function do_set() {
  local sec="$1" label="${2:-$1}"
  has_timer "$label"  && (( $(sec_left "$label") < 0 )) && unset_timer "$label"
  has_timer "$label"  && say_running "$label" || set_timer "$label" "$sec"
}

function do_cancel() {
  local label=${1}
  [[ $label == "that" ]] && label="$Last"
  has_timer "$label" && cancel_timer "$label" || say_none "$label"
  speak "you have $(say_number "${#Timers[@]}" timer) remaining."
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
    speak "cancelling $(say_number "${#Timers[@]}" timer)."
    for i in "${!Timers[@]}"; do
      cancel_timer "$i"
    done
}

# describe all timers, removing all expired timers
function do_query_all() {
  local s_running s_expired
  local running=0 total=0
  local seconds started pid added
  for label in "${!Timers[@]}"; do
    read -r seconds started pid added <<< "${Timers[$label]}"
    left=$(sec_left_helper "$seconds" "$started" "$added")
    (( left + seconds < 0 )) && { unset_timer "$label" ; continue ; }
    (( total=total + 1 ))
    local say=" The, $(say_timer "$label") timer "
    (( left == 0 )) && s_expired+="$say has just expired."
    (( left > 0 )) && { s_running+="$say has $(say_time_left "$label") left." ; ((running=running + 1)) ; }
    (( left < 0  )) && { s_expired+="$say expired $(say_time_left "$label") ago." ; unset_timer "$label" ; }
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
  local label="$1" delta_sec="$2" say_delta="$3"
  local left seconds started pid added note=""
  left=$(sec_left "$label")

  (( left < 0 )) && note+="recently expired"
  (( left + delta_sec < 0 )) && {
    speak "The $(say_timer "$label") expired too long ago, create a new timer"
    unset_timer "$label"
    return
  }
  read -r seconds started pid added <<< "${Timers[$label]}"
  added=$((added + delta_sec))
  kill "$pid"
  local sleep_for=$((left + delta_sec))
  speak "adding $say_delta to the $note $(say_timer "$label") timer, now with $(say_time "$sleep_for") left"
  start_timer "$label" "$seconds" "$added" "$sleep_for"
}

function unset_timer() {
  local label="$1"
  unset Timers["$label"]
  [[ $label == "$Last" ]] && Last=""
  debug "$label"
  return 0
}

function do_delta() {
  local label="${1:-$2}" delta="$3" sec="$(delta_to_sec "$delta")"
  has_timer "$label" && add_to "$label" "$sec" "$delta" || \
  speak "There is no $(say_timer "$label") timer to add $delta to."
}

function do_command {
  debug "$(declare -p Args)"
  local command="${Args[action]}"
  local label="${Args[label]}"
  local minutes="${Args[minutes]:-0}"
  local seconds="${Args[seconds]:-0}"
  local delta="${Args[delta]}"
  [[ $label == "that" ]] && label="$Last"
  case $command in 
    alarm)      do_alarm "$label" "${Args[added]}" ;;
    set)        do_set "$((minutes * 60 + seconds))" "$label";;
    cancel)     do_cancel "$label" ;;
    help)       do_help ;;
    cancel_all) do_cancel_all ;;
    queryall)   do_query_all ;;
    add)        do_delta "$label" "$((minutes * 60 + seconds))" "$delta" ;;
    reload)     speak "reloading"; . ./timers.bash;;
    *) speak "command, $command, not understood" ;;
  esac
}

# read and process events
function event_loop  {
  local line
  while read -r line; do
    case "$line" in
    command*)
      get_now
      do_command
      unset Args
      declare -Ag Args
    ;;
    *=*)
      IFS="=" read -r n v <<< "$line"
      Args["$n"]="$v"
    ;;
    esac
  done
}

function init() {
  trap 'kill $(jobs -p)' EXIT
  rm -f fifo;mkfifo fifo # event Q
  rm -f pids;mkfifo pids # to pass subshell PID
  get_now
}

function main() {
  init
  (watch $HOST Timer | extract > fifo) &
  < fifo event_loop
  echo "main exit"
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
echo "run 'main' to start"
