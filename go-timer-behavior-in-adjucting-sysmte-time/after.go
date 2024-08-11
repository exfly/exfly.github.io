package main

import (
	"log"
	"time"
)

func main() {
	sleepTime := time.Hour
	for {
		select {
		case <-time.After(sleepTime):
			log.Print("waitup and then sleep.")
		}

		time.Sleep(time.Second * 5)
	}
}
