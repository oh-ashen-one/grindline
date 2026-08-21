#!/bin/bash
# Sim gate: tools/verify-sim.sh <TestName> [timeout_s]
# Runs game/sim/SimRunner.tscn with --test=<TestName>. The test must print
# `SIM RESULT {...}` and quit(0) on pass, quit(1) on fail.
set -uo pipefail
source "$(dirname "$0")/env.sh"
TEST=${1:?usage: verify-sim.sh <TestName> [timeout_s]}
TIMEOUT=${2:-120}
cd "$GAME_ROOT/game"
[ -f "sim/tests/$TEST.gd" ] || { echo "missing sim test: sim/tests/$TEST.gd"; exit 1; }
perl -e 'alarm shift; exec @ARGV' "$TIMEOUT" \
  "$GODOT" --headless --path . res://sim/SimRunner.tscn -- "--test=$TEST"
CODE=$?
[ $CODE -eq 142 ] && { echo "sim timed out after ${TIMEOUT}s"; exit 1; }
exit $CODE
