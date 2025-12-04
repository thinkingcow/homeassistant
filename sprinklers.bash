#!/bin/bash
# Interface to opensprinkler (under construction)

#  [Sprinkler]
#     sprinkler status (:){action:status}
#     pause sprinklers (:){action:pause}
#     cancel sprinkler pause (:){action:cancel}
#     set rain delay (:){action:rain}
#     clear rain delay (:){action:norain}

# Configuration parameters
MQTT_HOST=localhost          # host of mqtt server
MQTT_TOPIC=Sprinkler         # topic to read voice commands from
PASS_FILE=./opensprinkler.pswd
PASS=$(cat $PASS_FILE)
HOST=sprinkler # host of open sprinkler
declare -A Args   # Command arguments

LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

# Text to speak the provided time (in seconds)
function say_duration {
  local seconds="${1}" 
  local hours="$((seconds / 3600))"
  seconds="$((seconds % 3600))"
  local min="$((seconds / 60))"
  local sec="$((seconds % 60))"
  (( hours > 0 )) && say_number "$hours" hour ", "
  (( min > 0 )) && say_number "$min" minute " and "
  (( sec > 0 )) && say_number $sec second || echo "no seconds"
}

# convert hh:dd:ss to seconds
function time_to_seconds {
  IFS=: read -r h m s <<< "$1"
  [[ -z "$m" ]] && { echo "$h" ; return; }
  [[ -z "$s" ]] && { s="$m"; m="$h"; h=0; }
  echo "$(( h * 3600 + m * 60 + s))"
}

# Fetch some JSON from opensprinkler
function fetch_sprinkler {
  local cmd=${1:-ja}
  curl -s "http://${HOST}:8080/$cmd?pw=$PASS"
}


# Emit speakable text for System pause time remaining
# $1: Output from fetch_sprinkler
# return: 0 (and emit "") if not paused

function pause_time {
  local l=$(jq -r .settings.pt <<< "$1")
  (( l )) && \
    echo "system paused with $(say_duration "$l") remaining" || \
    echo ""
  return "$l"
}

# delay expiration in seconds
function rain_delay_time {
  local l=$(jq <<< "$1" -r '.settings | .rdst - .devt')
  echo "$l"
  }

# Issue a "pause" to the system
# $1: seconds to pause (default to 10 minutes, 0 to disable existing pause)
function pause_system {
  local sec=$(time_to_seconds "${1:-10:00}")
  curl -s "http://${HOST}:8080/pq?pw=${PASS}&dur=$sec"
}

# Command to run a station in manual mode
# $1: station index: 0-7
# $2: Duration in seconds (0 to turn off station)
function run_station {
  local station="${1}"
  local time=$(time_to_seconds "${2:-15}")
  local enable=1
  (( time == 0 )) && enable=0
  curl -s "http://${HOST}:8080/cm?pw=${PASS}&sid=$station&en=$enable&t=$time"
}

# set rain delay in hours (0 to reset)
function rain_delay_hours {
  local hours=${1:-24}
  curl -s "http://${HOST}:8080/cv?pw=${PASS}&rd=$hours"
}

# wl=[0-250]
function set_water_pct {
  local pct=${1:-100}
  curl -s "http://${HOST}:8080/co?pw=${PASS}&wl=$pct"
}

# Fetch all the station names into the Names array
# $1: Output from fetch_sprinkler
declare -ag Names
function get_station_names {
  local l=$(jq -r '.stations.snames[]'  <<< "$1")
  Names=()
  while read -r line ; do
    Names+=("$line")
  done <<< "$l"
}

function get_option {
  local option=${2:=wl}
  jq -r ".options.$option"  <<< "$1"
}

# get text describing the running staion, if any, or "" of none running
function get_running_text {
  get_station_names "$1"
  local l=$(jq -r '.settings.ps[][1]' <<< "$1")
  local i=0
  while read -r line ; do
    (( line )) && {
       echo "zone ${Names[$i]} is running with $(say_duration "$line") remaining"
       return
    }
    i=$(( i++ ))
  done <<< "$l"
  echo ""
}

# pause command
function do_pause {
  local j="$(fetch_sprinkler)"
  local t="$(jq -r .settings.pt <<< "$j")"
  if [[ "$t" == 0 ]] ; then
    pause_system 15:00 
    speak "Pausing System for 15 minutes"
  else
    speak "system already paused with $(say_duration "$t") remaining"
  fi
}

function do_rain {
  rain_delay_hours
  speak "setting one day rain delay"
}

function do_norain {
  local j="$(fetch_sprinkler)"
  local d="$(rain_delay_time "$j")"
  if [[ d -gt 0 ]] ; then
    speak "cancelling $(say_duration $d) rain delay"
    rain_delay_hours 0
  else
    speak "no rain delay to cancel"
  fi
}

function do_level {
  local pct=${1:-100}
  set_water_pct "$pct"
  speak "Setting water level to $pct percent"
}

# pause cancel command
function do_cancel {
  local j="$(fetch_sprinkler)"
  local t="$(jq -r .settings.pt <<< "$j")"
  if [[ "$t" == 0 ]] ; then
    speak "no pause to cancel"
  else 
     pause_system 0 
     speak "Pause cancelled with $(say_duration "$t") remaining" ;
  fi
}

function do_status {
  local j="$(fetch_sprinkler)"

  local pct="$(get_option "$j" wl)"
  [[ "$pct" -ne "100" ]] && speak "Watering duration is $pct percent"

  local t="$(get_running_text "$j")"
  if [[ -n "$t" ]] ; then
    speak "$t"
    return
  fi
  local d="$(rain_delay_time "$j")"
  if [[ d -gt 0 ]] ; then
    speak "Rain delay active with $(say_duration "$d")"
    return
  fi
  local p="$(pause_time "$j")"
  if [[ -n "$p" ]] ; then
    speak "$p"
    return
  fi
  speak "The sprinker system is idle"
}

# Gets called for each mqtt event
function do_command() {
  local command="${Args[action]}"
  case $command in
    status) do_status ;;
    cancel) do_cancel ;;
    pause) do_pause ;;
    rain) do_rain ;;
    norain) do_norain ;;
    level) do_level "${Args[pct]:-100}" ;;
    *)
      speak "sprinkler $command, is not implemented"
      ;;
  esac
}

function main {
  debug "starting sprinkler controller"
  simple_main Sprinkler
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
