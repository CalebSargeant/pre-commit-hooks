#!/usr/bin/env bash
set -Eeuo pipefail

# Lightweight wrapper to run local file-quality checks without nesting pre-commit
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/file-quality.sh"
