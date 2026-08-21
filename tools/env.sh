#!/bin/bash
# Shared env for GRINDLINE verify helpers. tools/ is one deep: root is ..
export GODOT="${GODOT:-godot}"
export GAME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
