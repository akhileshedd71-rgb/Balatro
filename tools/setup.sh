#!/usr/bin/env bash
# Reproduce the prepared cloud development environment without changing source.
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
godot_version="$("$GODOT_BIN" --version)"
if [[ "$godot_version" != 4.6.3.* ]]; then
    printf 'Expected Godot 4.6.3; found %s\n' "$godot_version" >&2
    exit 1
fi
"$PROJECT_ROOT/tools/install_templates.sh"
"$PROJECT_ROOT/tools/install_android.sh"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --editor --import
