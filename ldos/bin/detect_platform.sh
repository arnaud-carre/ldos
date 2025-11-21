#!/bin/bash
# Platform detection script
# Source this script to get LDOS_PLATFORM variable

# Use uname directly for platform detection
export LDOS_PLATFORM="$(uname -s)-$(uname -m)"
