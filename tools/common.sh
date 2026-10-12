#!/usr/bin/env bash
# Source this file from the other development scripts.
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$(dirname -- "$PROJECT_ROOT")/.godot-data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$(dirname -- "$PROJECT_ROOT")/.godot-cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$(dirname -- "$PROJECT_ROOT")/.godot-config}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    printf '%s\n' 'Godot 4.6.3 is required. Set GODOT_BIN to its executable.' >&2
    exit 1
fi
