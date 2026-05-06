#!/usr/bin/env bash
# dxo2photos.sh — Wrapper for dxo2photos.py
#
# Usage:
#   ./dxo2photos.sh "image1_dxo.jpg" "image with spaces_dxo.jpg" ...
#
# Filenames containing spaces must be quoted.
# The Python environment is set up automatically on the first run.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — adjust as needed
# ---------------------------------------------------------------------------
# Resolve the real location of this script — works through symlinks too
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
PYTHON="$VENV_DIR/bin/python"
DXO2PHOTOS="$SCRIPT_DIR/dxo2photos.py"
OUTPUT_DIR="$HOME/Pictures/ExportedImages"
COPY_FLAG="--copy"          # Leave empty ("") to move instead of copy

# ---------------------------------------------------------------------------
# Setup (runs once on first call, only if .venv does not exist yet)
# ---------------------------------------------------------------------------

# 1. Check for exiftool
if ! command -v exiftool &>/dev/null; then
    echo "[setup] Error: 'exiftool' is not installed." >&2
    echo "[setup] Please install it with: brew install exiftool" >&2
    exit 1
fi

# 2. Check for python3
if ! command -v python3 &>/dev/null; then
    echo "[setup] Error: 'python3' not found." >&2
    echo "[setup] Please install Python 3: https://www.python.org or brew install python3" >&2
    exit 1
fi

# 3. Create virtual environment and install packages (first run only)
if [[ ! -d "$VENV_DIR" ]]; then
    echo "[setup] Creating Python virtual environment ..." >&2
    python3 -m venv "$VENV_DIR" >&2
    echo "[setup] Installing Python packages ..." >&2
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip >&2
    "$VENV_DIR/bin/pip" install --quiet "Pillow>=9.0.0" "piexif>=1.1.3" >&2
    echo "[setup] Setup complete." >&2
fi

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    echo "Error: no image files specified." >&2
    echo "Usage: $0 <image1> [<image2> ...]" >&2
    exit 1
fi

if [[ ! -f "$DXO2PHOTOS" ]]; then
    echo "Error: dxo2photos.py not found: $DXO2PHOTOS" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Invocation — "$@" passes all filenames correctly, including those with spaces
# ---------------------------------------------------------------------------
"$PYTHON" "$DXO2PHOTOS" \
    --output-dir "$OUTPUT_DIR" \
    ${COPY_FLAG:+"$COPY_FLAG"} \
    "$@"
