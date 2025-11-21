#!/bin/bash
# Detect platform
source ../../ldos/bin/detect_platform.sh

export PATH=../../ldos/bin/${LDOS_PLATFORM}/vasm:$PATH
vc -O0 -notmpfile -nostdlib -o greetings.bin greetings.asm
