#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
engine="${GODOT:-godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$PWD/.godot/test-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$PWD/.godot/test-config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$PWD/.godot/test-cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" .godot/test-logs
run_check() {
  local log="$PWD/.godot/test-logs/$1.log"
  shift
  "$engine" --headless --path . "$@" > "$log" 2>&1
  cat "$log"
  if rg -q '^(SCRIPT ERROR:|ERROR:|FAIL:)' "$log"; then
    return 1
  fi
}
run_check import --editor --import --quit
run_check actor --script tests/actor_regression.gd
run_check acoustics --script tests/test_acoustics.gd
run_check navigation --script tests/test_navigation_ai.gd
run_check audio --script tests/test_audio.gd
run_check match --script tests/test_match.gd
run_check tutorial --script tests/test_tutorial.gd
run_check simulation --fixed-fps 60 -- --simulate --team-size=3 --rounds=4 --difficulty=1 --seed=27013 --duration=60 --report="$PWD/.godot/test-logs/simulation.json"
