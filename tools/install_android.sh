#!/usr/bin/env bash
# Minimal official SDK tools for Godot's prebuilt-template debug APK export.
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
export BALATRO_ANDROID_SDK="${BALATRO_ANDROID_SDK:-$(dirname -- "$PROJECT_ROOT")/.android-sdk}"
export BALATRO_ANDROID_DOWNLOADS="${BALATRO_ANDROID_DOWNLOADS:-$XDG_CACHE_HOME/downloads}"
if ! command -v java >/dev/null 2>&1; then
    printf '%s\n' 'Install OpenJDK 17 or newer before configuring Android exports.' >&2
    exit 1
fi
export BALATRO_JAVA_SDK="${JAVA_HOME:-$(dirname -- "$(dirname -- "$(readlink -f -- "$(command -v java)")")")}"
python3 "$PROJECT_ROOT/tools/install_android.py"
