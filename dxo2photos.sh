#!/usr/bin/env bash
# dxo2photos.sh — Wrapper for dxo2photos.py
#
# Usage:
#   ./dxo2photos.sh "image1_openWith.jpg" "image with spaces_openWith.jpg" ...
#
# Filenames containing spaces must be quoted.
# Run build_app.sh once before first use to set up the Python environment.

set -euo pipefail

# Ensure Homebrew tools are on the PATH (Apple Silicon: /opt/homebrew, Intel: /usr/local)
# This is especially important when called via AppleScript, which uses a minimal PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

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
COPY_FLAG=""                # Set to "--copy" to copy instead of move

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
if [[ ! -f "$PYTHON" ]]; then
    echo "Error: Python environment not found at $VENV_DIR" >&2
    echo "Please run build_app.sh first to set up the environment." >&2
    exit 1
fi

if [[ ! -f "$DXO2PHOTOS" ]]; then
    echo "Error: dxo2photos.py not found: $DXO2PHOTOS" >&2
    exit 1
fi

if ! command -v exiftool &>/dev/null; then
    echo "Error: 'exiftool' is not installed." >&2
    echo "Please install it with: brew install exiftool" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Error: no image files specified." >&2
    echo "Usage: $0 <image1> [<image2> ...]" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Invocation — "$@" passes all filenames correctly, including those with spaces
# ---------------------------------------------------------------------------
"$PYTHON" "$DXO2PHOTOS" \
    --output-dir "$OUTPUT_DIR" \
    ${COPY_FLAG:+"$COPY_FLAG"} \
    "$@"
