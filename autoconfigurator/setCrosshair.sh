#!/bin/bash

## IN THIS FILE
#
# Calibrate the Datalogic Gryphon GFS4400 barcode reader's aimer
#
# Set it to center of the reading area.
#

. common.sh #load common idioms

startServiceMode
waitabit
baudServiceMode
waitabit
echo -e "\$FA03760240\r" > $device  #Set crosshair coordinates
waitabit
saveAndExit
waitabit
baudNormalMode

