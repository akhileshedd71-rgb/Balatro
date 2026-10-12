#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
exec "$GODOT_BIN" --path "$PROJECT_ROOT" "$@"
