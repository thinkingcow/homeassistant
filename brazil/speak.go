// "speak" to grasshopper on the command line.
// Inject the recognised text into the MQTT stream
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/koron/go-mqtt/client"
)

func main() {
	var host = flag.String("h", "grasshopper", "MQTT server hostname")
	var verify = flag.Bool("v", false, "Speak the command first")
	flag.Parse()
	text := strings.ReplaceAll(strings.Join(flag.Args(), " "), "\"", "")
	if text == "" {
		log.Printf("usage: %s [options] <text to be recognized>\n", os.Args[0])
		flag.PrintDefaults()
		return
	}
	log.Printf("say: (%s)\n", text)
	c, err := client.Connect(client.Param{
		ID:   "example_publish",
		Addr: "tcp://" + *host + ":1883",
		Options: &client.Options{
			CleanSession: true,
			KeepAlive:    60,
			Logger:       log.New(os.Stderr, "MQTT-C", log.LstdFlags),
		},
	})
	if err != nil {
		log.Fatalf("Connect() failed: %v", err)
	}
	if *verify {
		json := fmt.Sprintf("{\"text\":\"%s\"}", text)
		err = c.Publish(client.AtMostOnce, false, "hermes/tts/say", []byte(json))
		if err != nil {
			log.Printf("Publish() failed: %v", err)
		}
	}
	json := fmt.Sprintf("{\"input\":\"%s\"}", text)
	err = c.Publish(client.AtMostOnce, false, "hermes/nlu/query", []byte(json))
	if err != nil {
		log.Printf("Publish() failed: %v", err)
	}
	err = c.Disconnect(false)
	if err != nil {
		log.Printf("Disconnect() failed: %v", err)
	}
}
