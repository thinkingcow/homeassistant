#!/bin/bash
# Say the time
# [Tod]

LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
source "$LIB_DIR/mqtt_library.bash"
dflt=$(cat /etc/timezone)

function do_tod() {
  local tz=${Args[place]:-$dflt}
  debug "zone: $tz"
  speak "It is $(TZ=$tz date ${2} "+%I:%M %P. %A %B %d." | sed 's/:0/: owe /')"
}

function main {
  debug "starting timeof day  hood controller"
  simple_main Tod do_tod
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
