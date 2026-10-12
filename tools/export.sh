#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
target="${1:-web}"
case "$target" in
    web) preset=Web; output="$PROJECT_ROOT/builds/web/index.html"; mode=--export-release ;;
    linux) preset=Linux; output="$PROJECT_ROOT/builds/linux/midnight-table.x86_64"; mode=--export-release ;;
    android) preset=Android; output="$PROJECT_ROOT/builds/android/midnight-table.apk"; mode=--export-debug ;;
    *) printf 'Usage: %s [web|linux|android]\n' "$0" >&2; exit 2 ;;
esac
mkdir -p "$(dirname -- "$output")"
touch "$PROJECT_ROOT/builds/.gdignore"
exec "$GODOT_BIN" --headless --path "$PROJECT_ROOT" "$mode" "$preset" "$output"
