#!/bin/bash
# Rhasspy module for simple kitchen ingredient units conversion

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

LIB_DIR="${BASH_SOURCE%/*}"
[[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
# shellcheck source=mqtt_library.bash
source "$LIB_DIR/mqtt_library.bash"

function frac() {
  printf %s "${Fractions[${Args[fraction]:-none}]}"
}
function den() {
  printf %s "${Density[${Args[ingredient]}]}"
}
function unit() {
  printf %s "${Units[${Args[unit]}]}"
}
function quant() {
  printf %s "${Args[quantity]:-0}"
}

function say_num() {
  num2words "${1}" | sed 's/ point.*//'
}

# do floating point calculations, rounded to nearest int
function calc() {
  debug "$*"
  printf "%.0f\n" "$(bc -l <<<"$*")" 
}

function do_convert() {
    declare -p Args
    local q="$(quant)" f="$(frac)"
    local expr="($q + $f) * $(den) * $(unit)"
    local g="$(calc "$expr")"
    case "$q:$f" in
      0:*)
        speak "${Args[fraction]} ${Args[unit]} of ${Args[ingredient]} weighs: $(say_num "$g") grams"
        ;;
      *:0)
        speak "${Args[quantity]} ${Args[unit]} of ${Args[ingredient]} weighs: $(say_num "$g") grams"
        ;;
      *)
        speak "${Args[quantity]} and ${Args[fraction]} ${Args[unit]} of ${Args[ingredient]} weighs: $(say_num "$g") grams"
        ;;
    esac
}
function die () {
  echo "died" > /dev/stderr
}
function main {
  debug ""
  simple_main Convert do_convert die
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
