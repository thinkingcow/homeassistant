# home-assistant
Control modules for handling Rhasspy intents.  These are standalone
executables, written in bash, that interpret and respond to Rhasspy voice commands via
the MQTT intent messages.  I usually start whatever modules I like with
either an at-bootup script, or a systemd service module, pointed at the
proper MQTT server.  Whenever Rhasspy is running, they do their thing.

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
So there!

## Library
*mqtt_library.bash* is the library providing the *API* to interface bash scripts with
the Rhasspy intent system.  It reads and parses JSON commands from Rhasspy, and calls
the supplied command processor.

## Modules
## timers
A kitchen timer module.  Supports multiple kitchen timers via voice command

### convert
Food unit volume to weight conversions

### music
mpd music player command/control

## Installation
- [Install Rhasspy](https://rhasspy.readthedocs.io/en/latest/installation/#debian)
- Install remaining dependencies `sudo apt install screen mosquitto-clients bc jq`
- Start Rhasspy, and navigate to the browser interface (usually `http://localhost:12101).  From there,
  you can:
  - Configure the Rhasspy profile. I use [this one](rhasspy-profile.json).
  - install [`sentences.txt`](sentences.txt)` as the sentence templates.
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
would be nice too.
- This repo is still being assembled from scattered parts.
