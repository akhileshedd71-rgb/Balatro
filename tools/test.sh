#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
test_log="$(mktemp)"
test_data_dir="$(mktemp -d)"
trap 'rm -f "$test_log"; rm -rf "$test_data_dir"' EXIT
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --editor --import 2>&1 | tee "$test_log"
if rg -q 'SCRIPT ERROR:|Parse Error:|ERROR:' "$test_log"; then
    printf '%s\n' 'Godot import reported errors.' >&2
    exit 1
fi
shopt -s nullglob
test_files=("$PROJECT_ROOT"/tests/test_*.gd)
if ((${#test_files[@]} == 0)); then
    printf '%s\n' 'No tests/test_*.gd SceneTree test runners found.' >&2
    exit 1
fi
for test_file in "${test_files[@]}"; do
    test_resource="res://tests/$(basename -- "$test_file")"
    printf '\nRunning %s\n' "$test_resource"
    XDG_DATA_HOME="$test_data_dir/$(basename -- "$test_file" .gd)" \
        "$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script "$test_resource" 2>&1 | tee "$test_log"
    if rg -q 'SCRIPT ERROR:|Parse Error:|ERROR:' "$test_log"; then
        printf 'Godot test reported errors: %s\n' "$test_resource" >&2
        exit 1
    fi
done
