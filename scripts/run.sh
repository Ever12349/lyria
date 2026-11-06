#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c debug
BIN=".build/debug/Lyria"
exec "$BIN"
