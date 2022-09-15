# homeassistant*
Control modules for handling Rhasspy intents.  These are standalone
executables that interpret and respond to Rhasspy voice commands via
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
    - jq
    - mosquitto-clients

## Rhasspy Configuration
   see: [sample config file](rhasspy-profile.json)
   Note the "sound" section to configure the USB mic/speaker.

## Rasspy-timers
A kitchen timer module.  Supports multiple kitchen timers via voice command

## rhasspy-food-units-conversion
Food unit volume to weight conversions

## rhasspy-music
mpd music player command/control

## Notes
- The primary purpose of this repo is to allow me to recreate my setup if I loose a local copy.  If anyone else finds this to be useful, that would be nice too.
- This repo is still being assembled from scattered parts.
- TODO: refactor common code fragments into library, add Makefile to build executables
