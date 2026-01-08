#!/bin/bash
# choose a radio station for a given genre (mostly) arbitrarily
# using the Community Radio Station Index
#  (https://fi1.api.radio-browser.info/)
# TODO: this is a POC, need to figre out something sensible
# Sentences:
#  [Stream]
#  genres=(jazz|baroque...){genre}
#  stream a <genres> station

MPC_HOST=pi5
LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
echo "LIB_DIR=($LIB_DIR)" > /dev/stderr
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

# Choose an arbitrary "popular" station with the provided tag.
function choose_station() {
  local genre=${1:-jazz}
  local limit=${2:-9}
  local ua=thinkingcow/grasshopper
  local host=$(host -t srv _api._tcp.radio-browser.info | 
    sed -r 's/.* (.*)[.]$/\1/' | 
    shuf -n 1)
  debug "stream database host: $host"

  local args="order=votes&reverse=true&limit=$limit"
  local station=$(curl -s -A "$ua"  \
     "https://$host/json/stations/bytag/${genre// /%20}?$args" |
     jq -r '.[].url_resolved' |
     shuf -n 1)
  echo "$station"
}

function mpc_cmd() {
  debug "--host $MPC_HOST -q $*"
  mpc --host $MPC_HOST -q "$@"
}

function do_command() {
  local genre="${Args[genre]}"
  speak "Looking for a, $genre, stream"
  local station=$(choose_station "$genre")
  if [[ -n "$station" ]] ; then
    mpc_cmd clear
    mpc_cmd add "$station"
    mpc_cmd play
  else
    speak "Could not find a suitable station"
  fi
}

function main {
  debug "starting random audio stream controller"
  simple_main Stream
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
