#!/bin/bash
# Interface to opensprinkler (under construction)

#  [Sprinkler]
#     sprinkler status (:){action:status}
#     pause sprinklers (:){action:pause}
#     cancel sprinkler pause ():{action:cancel}

# Configuration parameters
MQTT_HOST=localhost          # host of mqtt server
MQTT_TOPIC=Sprinkler         # topic to read voice commands from
PASS=***		     # opensprinkler password
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
  return $l
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
  (( $time == 0 )) && enable=0
  curl -s "http://${HOST}:8080/cm?pw=${PASS}&sid=$station&en=$enable&t=$time"
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
    say "Pausing System for 15 minutes"
  else
    say "system already paused with $(say_duration "$t") remaining"
  fi
}

# pause cancel command
function do_cancel {
  local j="$(fetch_sprinkler)"
  local t="$(jq -r .settings.pt <<< "$j")"
  if [[ "$t" == 0 ]] ; then
    say "no pause to cancel"
  else 
     pause_system 0 
     say "Pause cancelled with $(say_duration "$t") remaining" ;
  fi
}

function do_status {
  local j="$(fetch_sprinkler)"
  local t="$(get_running_text "$j")"
  if [[ -n "$t" ]] ; then
    say "$t"
    return
  fi
  local p="$(pause_time "$j")"
  if [[ -n "$p" ]] ; then
    say "$p"
    return
 fi
 say "The sprinker system is idle"
}

# Gets called for each mqtt event
function do_command() {
  local command="${Args[action]}"
  case $command in
    status)
      do_status
      ;;
    cancel)
      do_cancel
      ;;
    pause)
      do_pause
      ;;
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
