## Abstract
Provide a simple mobile friendly web interface to the Grasshopper home
assistant.  This works by injecting text into the MQTT stream that 
represents recognized text.  See "Sentences.txt" for valid text strings.

## Summary
I use an old java based webserver I wrote decades ago called "brazil".
It's a testament to the backwards compatibility of Java that a system
that was written for JDK 1.1 still works. As this for my "home" network, 
it uses "http" instead of "https".  Although Brazil supports SSL/TLS, it's easier
to run it behind a Caddy reverse proxy if "https" is required, as Caddy manages the
certifcates automatically.

I've included a snapshot of a brazil Release as:
  brazil-18-Aug-09.jar
The jar file contains all the source code and documentation for Brazil. Run:
  java -jar brazil-18-Aug-09.jar port 8080
and navigate to "http://localhost:8080" to view the documentation.

## Files:
brazil-18-Aug-09.jar:
   Self contained Java based webserver
brazil.config:
   Brazil server configuration for the webserver
brazil.service:
   Systemd service to start web service on startup
favicon.ico:
grasshopper.svg:
tabbed.bsl:
   The web site.  Navigate to http://localhost:8080/
   This page has several configuration parameters that may be specified as
   query parameters These are intended for use with "shortcuts" on mobile devices
   to alter the
     verbose [false] (speaks the text first: needs "speak" built from source)
   These are intended for use with "shortcuts" on mobile devices
   to alter the size and spacing of various UI elements for best "fit"
     spacing [130]
     size [130]
     button [110];
     radius [20]
     margin [1]
     select [160]
speak:
   Staticially linked binary for the Rhaspberry PI
speak.go:
   Standalone "go" app to send text to the Rhasspy MQTT channel that
   simulates speech recognition.  I could just call "mosquitto_pub",
   but this was harder.  (Actually, using mosquitto_pub requires the
   optional json.jar to generate the mqtt messages, and that complicates
   running the server)
   To build and install (or use the included one):
     - install GO (v 1.1.18 or higher)
     - mkdir speak; cp speak.go speak; cd speak
     - go mod init speak
     - go build
     - cp speak /usr/local/bin
   make sure the resultant "speak" binary is in your path
