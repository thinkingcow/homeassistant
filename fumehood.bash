#!/bin/bash
# voice control of tasmota connected fume hood
# Sentences:
# [Tasmota]
#    turn (on|off){state} the fume hood


URL="http://192.168.1.65"
LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

# TODO: add "what" to speak current fumehood state
function do_command() {
  local state="${Args[state]}"
  speak "turning the fume hood $state"
  curl -s -o /dev/null -m 10 "$URL/cm?cmnd=Power%20$state" || speak "Oops, Something went wrong"
}

function get_state() {
  curl -s "$URL/cm?cmnd=Power" | jq -r .POWER
}

function main {
  debug "starting fume hood controller"
  simple_main Tasmota
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
