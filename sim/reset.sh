#!/usr/bin/env bash
# Put the local "GitHub" and every team member back to the starting point.
source "$(dirname "$0")/lib.sh"
reset_world
echo "World reset: everyone is on a clean main at sim-start."
