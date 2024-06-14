#!/bin/bash
# Recall what last recognized text was.
# Example using FIFO an as event Queue
# Sentences:
#   [Debug]
#   What did you hear (:){action:what}

HOST=localhost
TOPIC=Debug

LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
SOUND_DIR="$LIB_DIR/sounds"
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

# Generate recognized utterances, one per line
function recognized() {
  debug "listen for recognized text"
  mosquitto_sub -h $HOST -F %J -t hermes/nlu/textCaptured |
    jq -r --unbuffered '.payload.input'
}

# Enqueue each line
function to_queue() {
  local name=${1:-heard}
  debug "$name to ${TOPIC}_fifo"
  while read -r line; do
    enqueue ${TOPIC}_fifo "$name=$(fix_words "$line")"
  done
}

function fix_words() {
  sed -u 's/<unk>/blah/g'
}

prev="Nothing"
function do_command {
  [[ -v "Args[heard]" ]] && { prev="$current" ; current="${Args[heard]}" ; } || \
    speak "I heard. $prev."
}

# Give "main" time to create the fifo
(sleep 2; recognized | to_queue heard) &
queue_main $TOPIC do_command ${TOPIC}_fifo
