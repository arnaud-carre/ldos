#!/bin/bash
# Detect platform
source ../ldos/bin/detect_platform.sh

cd greetings || exit
./m.sh
cd ../sprites_loader || exit
./m.sh
cd .. || exit
# you could use LSPConvert -amigapreview command to generate a .wav file of your music
../ldos/bin/${LDOS_PLATFORM}/LSPConvert parcade.mod -getpos
../ldos/bin/${LDOS_PLATFORM}/ldos script.txt ldos_demo.adf
# Open in your preferred emulator
open ldos_demo.adf
