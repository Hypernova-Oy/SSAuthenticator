#!/bin/bash

## IN THIS FILE
#
# Load common idioms for configuring the Datalogic Gryphon GFS4400 barcode reader
#

device="/dev/ttyACM1"
echo="echo -ne"

function waitabit {
  sleep 1
}

function waitsomemore {
  sleep 3
}

function baudServiceMode {
  stty -F $device 115200
}

function baudNormalMode {
  stty -F $device 9600
}

function startServiceMode {
  $echo "\$S\r" > $device
}

function saveAndExit {
  $echo "\$Ar\r" > $device
}
