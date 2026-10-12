#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [[ ! -f "$PROJECT_ROOT/builds/web/index.html" ]]; then
    printf '%s\n' 'Export first: ./tools/export.sh web' >&2
    exit 1
fi
exec python3 -m http.server "${PORT:-8060}" --bind "${BIND:-127.0.0.1}" --directory "$PROJECT_ROOT/builds/web"
