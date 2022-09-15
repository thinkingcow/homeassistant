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


MQTT_HOST=localhost
MPC_HOST=pi5
cd /home/suhler/assistant

function watch() {
  local topic=${1:-Radio}
  mosquitto_sub -h $MQTT_HOST -t hermes/intent/$topic 
}

# Extract slots from a timer event as name=value pairs.
#   add a dummy slot "command=xxx" at the end to trigger the action.
function extract {
   jq --unbuffered -r \
   '.slots|map({(.slotName):.value.value})|. += [{"command":"convert"}]|add|to_entries[]|join("=")' 
}

function say {
 local text="${1:-hello}"
 debug "$text"
 mosquitto_pub -h $MQTT_HOST -t hermes/tts/say -m '{"text":"'"$text"'"}'
 return 0
}

function debug {
  echo "convert ${FUNCNAME[1]}: $*" > /dev/stderr
}

function mpc_what() {
  mpc --host $MPC_HOST  -f "%title% [%artist%]|[%name%]" | sed -u '2,$d'
}

function do_vol() {
  local step=${1:-+10}
  mpc --host $MPC_HOST -f "" volume $step | sed -r -e '/volume:/!d' -e 's/volume: ([0-9]+).*/\1/'
}

function do_playlist() {
  mpc_cmd clear
  mpc_cmd load "$1"
  mpc_cmd play
}

function mpc_cmd() {
  mpc --host $MPC_HOST -q $*
}

function do_command() {
  local command="${Args[action]}"
  case $command in
    play | resume)
      say "turning on the radio"
      mpc_cmd play
      ;;
    pause)
      mpc_cmd pause
      say "radio paused."
      ;;
    next)
      mpc_cmd next 
      say "now playing. $(mpc_what)"
      ;;
    previous)
      mpc_cmd prev 
      say "now playing. $(mpc_what)"
      ;;
    increase | raise)
      vol="$(do_vol +10)"
      say "volume increased to $vol percent"
      ;;
    decrease | lower)
      vol="$(do_vol -10)"
      say "volume decreased to $vol percent"
      ;;
    select | "tune to")
      do_playlist "$(tr -d " " <<< ${Args[playlist]})"
      say "playing from ${Args[playlist]}"
      ;;
    what)
      say "Currently playing $(mpc_what)"
      ;;
    *)
      say "$command, is not implemented"
      ;;
  esac
}

function event_loop  {
  while read -r line; do
    case "$line" in
      command*)
        debug "$(declare -p Args)"
        do_command
        unset Args
        declare -Ag Args
      ;;
      *=*)
        IFS="=" read -r n v <<< "$line"
        Args[$n]="$v"
      ;;
    esac
  done
}

function main {
  trap 'kill $(jobs -p)' EXIT
  declare -Ag Args
  watch Radio | extract | event_loop
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
