#!/bin/bash
# XXX NOT DONE
# voice control for weather.gov forecast api
# Sentences:
# [Weather]
#    when=(Afternoon|Sunday|Monday|Tuesday|Wednesday|
#          Thursday|Friday|Saturday|Today|Tonight|Tomorrow){when}
#    What is the weather [this] <when> [Night]{night} (:){action:when}
#    weather summary (:){action:summary}

#  [Weather]
#    when=(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|
#        Saturday|Today|Tonight|Tomorrow)
#    What is the weather [this] <when> [Night]
#    Weather Summary

LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
echo "LIB_DIR=($LIB_DIR)" > /dev/stderr
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

# Convert lat,lon into grid number
function get_grid() {
	lat=${1:-37.4009712}
	lon=${2:--122.1235118}
	curl -s -L "https://api.weather.gov/points/${lat},${lon}" |
	jq -r -c '.properties|{x:.gridX , y:.gridY}|join(",")'
}

# fetch basic forecast
# TODO: Station should match endpoint
function fetch_forecast() {
	local grid=${1:-92,87}
	local station=${2:-MTR}
	local endpoint=${3:-forecast}
	curl -s "https://api.weather.gov/gridpoints/$station/$grid/$endpoint"
}

# Extract time period name, short, and long forecast descriptions
function parse_text() {
	jq --unbuffered -r '.properties.periods[] |
	 	{name: .name, detail: .detailedForecast, summary: .shortForecast} |
		to_entries[]|join("=")'
}

# extract parse_text info into array and return it
#  name=Today
#  detail=Rain. Mostly cloudy. High near 59, with ...
#  summary=Light Rain
#  ...
# 

function extract() {
	unset Data
  declare -A Data
	local key=invalid
	local count=0
  while read -r line; do
    IFS="=" read -r n v <<< "$line"
		case "$n" in 
    name)
      ((count++))
		  key="$v"
			Data["$count"]="$key"
			;;
		detail|summary)
      Data["${key}_$n"]="$v"
			;;
		*) 
			debug "ignore: $v ($line)"
			;;
	  esac
  done
	declare -p Data
}

function tomorrow() {
	date +%A -d '+1 day'
}

function today() {
	date +%A
}

function do_command() {
	debug "Args: $(declare -p Args)"
	eval "$(fetch_forecast | parse_text | extract)"
  for i in "${!Data[@]}"; do echo "Data: ${i}=${Data[$i]:0:20}"; done
  case "${Args[action]}" in 
  summary)
		local text="Weather summary. "
		for i in 1 2 3 4 5; do
			local when=${Data[$i]}
			text+="$when: ${Data[${when}_summary]}. "
		done
		speak "$text"
		;;
	when)
		local i="${Args[when]}"
		debug "start=$i"
		[[ "$(today)" = "$i" ]] && i="Today"
		[[ "Tomorrow" = "$i" ]] && i="$(tomorrow)"
		[[ "$i" = "Today" ]] && [[ ! -v Data["${i}_detail"] ]] && i=${Data[1]}
		[[ ${Args[night]} == "Night" ]] && i+=" Night"
		[[ "$i" = "This Afternoon Night" ]] && i="Tonight"
		debug "end=$i"

		local t
		[[ -v Data[${i}_detail] ]] && t=${Data[${i}_detail]} || t="unknown"
		speak "$i. $t"
		;;
	*)
		speak "invalid weather request"
	esac
}

function main {
  debug "starting weather controller"
  simple_main Weather
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
