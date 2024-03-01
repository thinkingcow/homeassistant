#!/bin/bash
# XXX NOT DONE
# voice control for weather.gov forecast api
# Sentences:
#  [Weather]
#    weather=(Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Today, Tonight Tomorrow)
#  What is the weather {weather} [tonight]

LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
echo "LIB_DIR=($LIB_DIR)" > /dev/stderr
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

function call_api() {
	local grid=${1:-92,87}
	curl -s https://api.weather.gov/gridpoints/MTR/$grid/forecast
}

# extract forecast info into name=value pairs
#  name=Today
#  detail=Rain. Mostly cloudy. High near 59, with ...
#  summary=Light Rain
#  ...
# 

function parse() {
	jq --unbuffered -r '.properties.periods[] |
	 	{name: .name, detail: .detailedForecast, summary: .shortForecast} |
		to_entries[]|join("=")'
}

function extract() {
	unset Data
  declare -A Data
	local today=$(today)
	local tomorrow=$(tomorrow)
	local key=invalid
  while read -r line; do
    IFS="=" read -r n v <<< "$line"
		case "$n" in 
    name)
		  key="$v"
			;;
		detail)
      Data["$key"]="$v"
		  [[ $key == "$tomorrow" ]] && Data["Tomorrow"]=$v
		  [[ $key == "Today" ]] && Data[$today]=$v
			;;
		*) 
			debug "ignore: $v ($line)"
			;;
	  esac
  done
	declare -p Data
}

function do_command() {
	debug "Args: $(declare -p Args)"
	eval "$(call_api | parse | extract)"
  for i in "${!Data[@]}"; do
    echo "Data: ${i}=${Data[$i]}"
  done
	speak "Tomorrow."
	speak "${Data["Tomorrow"]}"
}

function tomorrow() {
	date +%A -d '+1 day'
}

function today() {
	date +%A
}

function main {
  debug "starting weather controller"
  simple_main Weather
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
