# home-assistant
Control modules for handling Rhasspy intents.  These are standalone
executables, written in bash, that interpret and respond to Rhasspy voice commands via
the MQTT intent messages.

## Introduction
I have a Google voice assistant thing in my kitchen, and had been using
it for kitchen related stuff.  Sadly, as time
has gone by, She (the Google assistant) has become less reliable for me.
First, I could no longer access my CD collection via voice control -
the one I painstakingly uploaded to Google Music.  So I couldn't listen
to my music while cooking.  Then one day, while I was cooking a
fancy dinner (and had several important timers set), I asked Google,
nicely I might add, to "stop playing (the radio)".  I was told "they are
cancelled": the radio continued to play, but all my timers got cancelled.
My pleas to "uncancel those timers" were met with nothing but derision.

That was the last straw.  Except for helping me cheat at the NYT daily puzzle, she's pretty useless*

So how hard could it be?


## Hardware
  - Raspberry PI 4
  ![Image of Raspberry Pi 4](https://assets.raspberrypi.com/static/raspberry-pi-4-labelled-f5e5dcdf6a34223235f83261fa42d1e8.png)
  - Jabra 410 USB conference mic/speaker
  ![Image of Conference mic](https://assets2.jabra.com/6/1/7/e/617e12faf4365e88def7c2564c28b2070e4bc3f1_Speak410_p1_new.png?w=200&h=200)

## Software
  - Latest 64 bit Raspberry PI OS
  - Rhasspy 2.5.11 (I know, it's likely abandonware, but whatever)
  - Additional Packages to *apt install*
    - jq (manipulates json)
    - mosquitto-clients (talks to the mqtt pub/sub system)
    - bc (floating point math for bash)
    - screen (to facilitate monitoring of modules)

## Rhasspy Configuration
   see: [sample config file](rhasspy-profile.json)
   Note the "sound" section to configure the USB mic/speaker.

## Why bash?
There is no justifyable reason for using bash for this application.  Bash is
good for defining configuration parameters and starting the command(s) that use
them in a declarative fashion.  If the logic is complex enough to require
conditional logic (e.g. if-then-else) then bash is likely the wrong tool for the job.

## Library
*mqtt_library.bash* is the library providing the *API* to interface bash scripts with
the Rhasspy intent system.  It reads and parses JSON commands from Rhasspy, and calls
the supplied command processor.

## Example Module
The included *mqtt_library* does most of the work interacting
with The Rasspy messages an the MQTT event broker.  Many voice
action modules are synchronous - they are provided with a command
with optiona arguments, manage some state, then speak the results.
These modules use *simple_main*.  The module below responds to the
query "what time is it" by speaking the current time.

```bash
  #!/bin/bash
  # Rhasspy module to Say the time of day
  # sentences.txt entries:
  #  [TOD]
  #  what time is it

  # boilerplate to import the mqtt library
  LIB_DIR="${BASH_SOURCE%/*}"
  [[ -d "$LIB_DIR" ]] || LIB_DIR="$PWD"
  source "$LIB_DIR/mqtt_library.bash"
  
  # Called for each command. Args[] contains all name/value arguments (not used)
  function do_tod() {
    speak "It is $(date "+%H:%M %P. %A %B %d.")"
  }

  function main {
    debug "starting timeof day server" # emit debugging
    simple_main Tod do_tod
  }

  # boilerplate
  [[ "${BASH_SOURCE[0]}" != "${0}" ]] || main
```

## Modules
## timers
A kitchen timer module.  Supports multiple optionally named kitchen timers via voice command.
See (sentences.txt) for the set of timer capabilities.

### convert
Food unit volume to weight conversions.  I like cooking by weight; this provides conversions for common ingredients when recipies are volume and not weight based.

### music
mpd music player command/control.  You will need to `sudo apt install mpc` for
this to work, and set your "mpc" host in the `music.bash` script

### fumehood
This turns on/off a [tasmota](https://tasmota.github.io/docs/) controlled
switch.  In my case, it is connected to a remote fume hood fan.  Make sure
to set the "URL" in fumehood.bash to match your switch.

### forecast
This reaches out to the weather.gov API for local weather forecasts.  It will
also use [sunwait](https://github.com/risacher/sunwait) to provide local sunset and
sunrise times. (The local park hours are keyed on those times).

### what
Reads the last recognized utterance.  Used for debugging, and to demonstrate the use
of a FIFO as an event queue to deal with multiple event streams asyncrhonously.

## Installation
- [Install Rhasspy](https://rhasspy.readthedocs.io/en/latest/installation/#debian)
- Install remaining dependencies
     ```sudo apt install screen mosquitto-clients bc jq```
- Start Rhasspy, and navigate to the browser interface (usually http://localhost:12101).  From there,
  you can:
  - Configure the Rhasspy profile. I use [this one](rhasspy-profile.json).
  - install [`sentences.txt`](sentences.txt) as the sentence templates.
  - install [`nouns.txt`](nouns.txt)' in the 'nouns' slot
  - install the names of your mpd playlists in the 'playlists' slot
- Verify the audio is working properly (to be added)
- start the modules by running `start_voice_commands`

## Notes
- The Rhasspy slot names "playlists" (no sample provided) should contain your desired mpd playlists.
- The *st{art,op}_voice_commands* scripts start the modules (and rhasspy if needed) in a "screen" session,
which allows easy monitoring and debugging of the modules
- The primary purpose of this repo is to allow me to recreate my setup
if I loose a local copy.  If anyone else finds this to be useful, that
would be nice.
- my assistant also knows how to cheat at the NYT puzzles, but I'm trying not to.
- This repo is still being assembled from scattered parts.

## 2024 Update
This repo is pretty old at this point, but It still works for me.
In fact I was adding calendar integration
(e.g. "when's my next Dr's appointment") when I broke it: an "apt upgrade"
made an incompatible change to something, and with its many moving parts and
dependencies, it's going to take a while to figure out how to get it working
again.  My plan is an upgrade to a Raspberry PI 5 so I can switch to better TTS.

In the meantime, this is the easiest way to get this stuff working from scratch on 
a Rhaspberry PI 4.  It uses old software which might not have the latest 
security patches, but it works and it's easy:
1. Fetch the last Bullseye release for the Rhaspberry PI: [2021-05-07-raspios-buster-arm64-lite.zip](https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2021-05-28/2021-05-07-raspios-buster-arm64.zip),
copy it to a sd card and use it to boot up the PI. 
```
  unzip 2021-05-07-raspios-buster-arm64.zip
  # insert new sd card via usb adaptor, verify device name, usually X=a
  sudo cp 2021-05-07-raspios-buster-arm64.img /dev/sdX
  sync
  # remove sd card from usb holder and insert into Pi 4
```

Configure the PI in the usual way (`raspi-config`),
making sure to enable `WIFI` and `ssh`.  This this release uses a default "pi" 
account and password, do change the password.

2. Fetch the Rhasspy debian package: 
[rhasspy_arm64.dev](https://github.com/rhasspy/rhasspy/releases/latest/download/rhasspy_arm64.deb).  If you use a newer version of the OS and try to install this package, you will find yourself in dependency hell.

3. Install Rhasspy
```
  sudo apt update
  sudo apt install ./rhasspy_arm64.deb
```
You should be able to run `rhasspy --profile en`, navigate to the Rhasspy
website and verify that it's working.

4.  Install the dependencies for this repository
```
 sudo apt install git jq mosquitto-clients bc screen
```
Git is required to fetch the repository, the rest are used by the intent
scripts

5. Configure Rhasspy.
Import the `rhasspy-profile.json`, `sentences.txt` and `foods.slot` into Rhasspy
using the web interface. You will likely be using a USB audio device, so the audio
device is set to `default:CARD=USB`, but you may need to futz with it
for your setup.

6. Download this repo:
``` 
  mkdir ~/git
  cd ~/git
  git clone https://github.com/thinkingcow/homeassistant.git
```
7.  Fire it up by running `./start_voice_commands` which starts Rhasspy and this repo's intent services, each in its own screen session.  You can use `screen -ls` to
see the screen sessions.

8. Set for startup on reboot by installing the systemd service.
Check (and edit)  `homeassistant.service` to ensure the path to
this directory is correct. Then run (as root)
```
  cp homeassistant.service /etc/systemd/system
  systemctl daemon-reload
  systemctl enable homeassistant.service
```
Make sure Rhaspberry isn't already running with `./stop_voice_commands` then

```
  systemctl start homeassistant.service
```
9. Misc notes:
   - `num2words`, used by `convert.bash` is included in the Rhasspy.deb package
      but doesn't work for me.  I copied the binary to /usr/bin, and changed
      the #! line to point to the Rhasspy installed version of python to fix it.
   -  Raspberry Pis chew through sd cards when configured as described
      here.  Consequently, about once per year you should swap out the
      sd card for a new one to minimise the chance of disk corruption.
      I find [rpi-clone](https://github.com/billw2/rpi-clone) works well
      for the task.
