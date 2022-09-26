#!/bin/bash
# voice control of mpc
# Sentences:
#  [Radio]
#    playlists=($playlists){playlist}
#    (play | resume | pause){action} (radio | music)
#    (next | previous){action} track
#    (increase | decrease | raise | lower){action} [the] volume
#    (select|tune to){action} [playlist] <playlists>
#    what (am I listening to | is playing) (:){action:what}


MPC_HOST=pi5

LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
echo "LIB_DIR=($LIB_DIR)" > /dev/stderr
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

function mpc_what() {
  mpc --host $MPC_HOST  -f "%title% [%artist%]|[%name%]" | sed -u '2,$d'
}

function do_vol() {
  local step=${1:-+10}
  mpc --host $MPC_HOST -f "" volume "$step" | sed -r -e '/volume:/!d' -e 's/volume: ([0-9]+).*/\1/'
}

function do_playlist() {
  mpc_cmd clear
  mpc_cmd load "$1"
  mpc_cmd play
}

function mpc_cmd() {
  mpc --host $MPC_HOST -q "$@"
}

function do_command() {
  local command="${Args[action]}"
  case $command in
    play | resume)
      speak "turning on the radio"
      mpc_cmd play
      ;;
    pause)
      mpc_cmd pause
      speak "radio paused."
      ;;
    next)
      mpc_cmd next 
      speak "now playing. $(mpc_what)"
      ;;
    previous)
      mpc_cmd prev 
      speak "now playing. $(mpc_what)"
      ;;
    increase | raise)
      vol="$(do_vol +10)"
      speak "volume increased to $vol percent"
      ;;
    decrease | lower)
      vol="$(do_vol -10)"
      speak "volume decreased to $vol percent"
      ;;
    select | "tune to")
      do_playlist "$(tr -d " " <<< "${Args[playlist]}")"
      speak "playing from ${Args[playlist]}"
      ;;
    what)
      speak "Currently playing $(mpc_what)"
      ;;
    *)
      speak "$command, is not implemented"
      ;;
  esac
}

function main {
	debug "starting mpd controller"
	simple_main Radio
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
