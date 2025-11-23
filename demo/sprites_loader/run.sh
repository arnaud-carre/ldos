#!/bin/bash
# Detect platform
source ../../ldos/bin/detect_platform.sh

./m.sh
../../ldos/bin/${LDOS_PLATFORM}/ldos script.txt sprite.adf

# Open ADF in your preferred emulator
open sprite.adf
