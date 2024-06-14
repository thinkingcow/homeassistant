# library of common MQTT functions used to build bash rhasspy voice control modules
MQTT_HOST=${MQTT_HOST:-localhost}    # host of mqtt server
SOUND_DIR=${SOUND_DIR:-sounds}       # directory to find sound files in.

# Print function name and args to stderr
function debug {
  echo "${BASH_SOURCE[-1]##*/} ${FUNCNAME[1]}: $*" > /dev/stderr
}

# Listen for timer events from mqtt
function watch_mqtt {
  local topic="$1"
  mosquitto_sub -h "$MQTT_HOST" -t "hermes/intent/$topic"
}

# Extract slots from an mqtt Rasspy message as name=value pairs.
# - add a dummy slot "command=done" at the end to trigger the action.
function extract_args {
  jq --unbuffered -r \
     '.slots|map({(.slotName):(.value.value|tostring)})|. += [{"command":"done"}]|add|to_entries[]|join("=")' 
}

# Play a sound file via MQTT
function play_wav() {
  local file=${1:-boing.wav}
  local id=${2:-dflt}
  debug "$file"
  mosquitto_pub -h "$MQTT_HOST" \
    -t "hermes/audioServer/default/playBytes/$id"\
    -f "$SOUND_DIR/$file"
}

# Text to speech (must succeed)
function speak {
  local text="${1:-hello}"
  debug "$text"
  mosquitto_pub -h "$MQTT_HOST" -t hermes/tts/say -m '{"text":"'"$text"'"}'
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

# put a command onto our Fifo
#  args: fifo name1=value1 name2=value2 ...
#  note: fatal error if fifo doesn't already exist
function enqueue() {
  local cmd="" fifo=${1:-fifo}
  [[ -p "$fifo" ]] || { debug "no fifo $fifo" ; exit 1; }
  shift
  debug "$fifo: $*"
  for i in "$@" ; do
    cmd+="$i"
    cmd+='\n'
  done
  cmd+='command=done'
  echo -e "$cmd" > "$fifo"
}

# read and process events
function event_loop  {
  local line func="${1:-do_command}"
  declare -Ag Args
  while read -r line; do
    case "$line" in
    command=done)
      debug "$(declare -p Args)"
      $func
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

function cleanup() {
  debug "$*"
  kill $(jobs -p)
  rm -f "$1"
}

# Sample main program
# args:
#  topic: the rhasspy intent topic to listen (e.g. the sentences [category])
#  func:  the function to call to run a command (defaults to do_command).
#         Args[] contains the name/value pairs of all the intent variables.
#  name of function to call on exit
function simple_main {
  local topic="$1"
  local func="$2"
  local exit_func=${3:-true}
  trap "cleanup; $exit_func" EXIT
  declare -Ag Args
  debug "$*"
  watch_mqtt "$topic" | extract_args | event_loop "$func"
  debug "terminated"
}

# Sample main program
#  Use when events external to the mqtt system are required.
#  See enqueue() to place an entry into the queue
# args:
#  topic: the rhasspy intent topic to listen (e.g. the sentences [category])
#  func:  the function to call to run a command (defaults to do_command).
#         Args[] contains the name/value pairs of all the intent variables.
#  queue  name of the fifo to use as the queue (default is ${topic}_fifo)
#  name of function to call on exit
function queue_main() {
  local topic="$1"
  local func="${2:-do_command}"
  local fifo="${3:-$topic-fifo}"
  local exit_func=${4:-true}

  trap "cleanup $fifo; $exit_func" EXIT
  rm -f "$fifo";mkfifo "$fifo" # event Q
  (watch_mqtt "$topic" | extract_args > "$fifo") &
  < "$fifo" event_loop "$func"
  debug "terminated"
}
# end of library
