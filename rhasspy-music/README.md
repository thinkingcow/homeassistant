# Manage the "mpc" music player
Music in the house is controlled via mpd, the music player daemon. I have fully featured web and
native clients for full control, this enables a subset of controls via voice command.
- Raise or Lower the volume
- Play or pause the current track
- select a playlist (defined in Rhasspy as a dictionary slot)
- next or previous track
- describe the current track

## Notes
- Set the MPD and MQTT hosts in the script config
- mpc must be installed
