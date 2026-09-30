#!/bin/sh
# tunnel_up.sh —— 薄壳：找到 python，把活交给 tools/tunnel_up.py（macOS / Linux）
# 用法: ./tunnel_up.sh [--port 8790] [--no-secret]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
if command -v python3 >/dev/null 2>&1; then PY=python3; else PY=python; fi
exec "$PY" "$HERE/tunnel_up.py" "$@"
