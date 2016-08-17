#!/bin/bash

## IN THIS FILE
#
# Sets the line ending for the Datalogic Gryphon GFS4400 barcode reader
# to \n aka. (LF) aka. UNIX new line
#

. common.sh #load common idioms

startServiceMode
waitabit
baudServiceMode
waitabit
$echo "\$CLFSU0D00000000000000000000000000000000000000\r" > $device     #Set Global Suffix (terminator) to LF
waitsomemore
saveAndExit
waitabit
baudNormalMode

