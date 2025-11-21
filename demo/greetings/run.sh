#!/bin/bash
# Detect platform
source ../../ldos/bin/detect_platform.sh

./m.sh
../../ldos/bin/${LDOS_PLATFORM}/ldos script.txt greetings.adf

# Open ADF in your preferred emulator
open greetings.adf
