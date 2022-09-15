#!/bin/bash
# Rhasspy module for simple kitchen ingredient units conversion

HOST=localhost
cd /home/suhler/assistant

function watch {
  mosquitto_sub -h $HOST -t hermes/intent/Convert 
}

# Extract slots from an intent as name=value pairs.
#   add a dummy slot "command=xxx" at the end to trigger the action.
function extract {
   jq --unbuffered -r \
   '.slots|map({(.slotName):.value.value})|. += [{"command":"convert"}]|add|to_entries[]|join("=")' 
}

# Text to speech (must succeed)

function say {
 local text="${1:-hello}"
 debug "$text"
 mosquitto_pub -h $HOST -t hermes/tts/say -m '{"text":"'"$text"'"}'
 return 0
}

function debug {
  echo "convert ${FUNCNAME[1]}: $*" > /dev/stderr
}

# densities of common foods: grams per cup
declare -A Density=(
  [baking powder]=230
  [baking soda]=230
  [brown sugar]=239
  [butter]=226
  [buttermilk]=242
  [canola oil]=215
  [chocolate chips]=170
  [egg]=56
  [flour]=120
  [honey]=340
  [milk]=240
  [olive oil]=215
  [peanut butter]=270
  [pecan pieces]=112
  [raisins]=156
  [rolled oats]=99
  [sour cream]=240
  [table salt]=273
  [salt]=273
  [kosher salt]=241
  [sugar]=198
  [water]=237
  [white sugar]=198
  [yoghurt]=242
)

declare -A Fractions=(
  [none]=0
  [an eighth]=0.125
  [one eighth]=0.125
  [a quarter]=0.25
  [one quarter]=0.25
  [a third]=0.333
  [one third]=0.333
  [half]=0.5
  [a half]=0.5
  [one half]=0.5
  [three eights]=0.375
  [three quarters]=0.75
  [two thirds]=0.6667
)

declare -A Units=(
  [cup]=1.0
  [cups]=1.0
  [pint]=2.0
  [pints]=2.0
  [quart]=4.0
  [quarts]=4.0
  [stick]=0.5
  [sticks]=0.5
  [tablespoon]=0.0625
  [tablespoons]=0.0625
  [teaspoon]=0.0208333
  [teaspoons]=0.0208333
)

function frac() {
  printf "${Fractions[${Args[fraction]:-none}]}"
}
function den() {
  printf "${Density[${Args[ingredient]}]}"
}
function unit() {
  printf "${Units[${Args[unit]}]}"
}
function quant() {
  printf "${Args[quantity]:-0}"
}

function say_num() {
  num2words ${1} | sed 's/ point.*//'
}

# Say a number with proper noun suffix.
function say_number() { 
  local number=${1}
  local noun=${2}
  local at_end=${3}
  case "$number" in
    0) echo -n "no ${noun}s";;
    1) echo -n "one $noun";;
    *) echo -n "$number ${noun}s";;
  esac
  echo -n "$at_end"
}

# do floating point calculations, rounded to nearest int
function calc() {
  debug "$*"
  printf "%.0f\n" "$(bc -l <<<"$*")" 
}

function do_convert() {
    declare -p Args
    local q="$(quant)"
    local f="$(frac)"
    local expr="($q + $f) * $(den) * $(unit)"
    local g="$(calc "$expr")"
    case "$q:$f" in
      0:*)
        say "${Args[fraction]} ${Args[unit]} of ${Args[ingredient]} weighs: $(say_num $g) grams"
        ;;
      *:0)
        say "${Args[quantity]} ${Args[unit]} of ${Args[ingredient]} weighs: $(say_num $g) grams"
        ;;
      *)
        say "${Args[quantity]} and ${Args[fraction]} ${Args[unit]} of ${Args[ingredient]} weighs: $(say_num $g) grams"
        ;;
    esac
}

# read and process events
function event_loop  {
  while read -r line; do
    case "$line" in
      command*)
        do_convert
        unset Args
        declare -Ag Args
      ;;
      *=*)
        IFS="=" read -r n v <<< "$line"
        debug "  $n=$v"
        Args[$n]="$v"
      ;;
    esac
  done
}
function main {
  trap 'kill $(jobs -p)' EXIT
  declare -Ag Args
  watch | extract | event_loop
}
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
