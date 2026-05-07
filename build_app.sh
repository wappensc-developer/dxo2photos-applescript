#!/usr/bin/env bash
# build_app.sh — Build script for dxo2photos (v2 pure-AppleScript)
#
# Compiles dxo2photos.applescript into an app bundle.
# Runtime dependency: exiftool only (no Python, no venv).
#
# Usage:
#   bash build_app.sh
#
# Optional symlink for Finder:
#   ln -s "$PWD/dxo2photos.app" /Applications/dxo2photos.app
#
# Register in DxO PhotoLab:
#   Preferences → External Programs → + → select dxo2photos.app

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$DIR/dxo2photos.app"

# ---------------------------------------------------------------------------
# 1. Check prerequisites
# ---------------------------------------------------------------------------
echo "[build] Checking prerequisites ..."

if ! command -v exiftool &>/dev/null; then
    echo "[build] Error: 'exiftool' is not installed." >&2
    echo "[build] Please install it with: brew install exiftool" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Generate app icon (requires Python + Pillow, skipped if .icns exists)
# ---------------------------------------------------------------------------
if [[ ! -f "$DIR/dxo2photos.icns" ]]; then
    if command -v python3 &>/dev/null; then
        echo "[build] Generating icon ..."
        python3 "$DIR/create_icon.py"
    else
        echo "[build] Warning: dxo2photos.icns missing and python3 not found — icon skipped." >&2
    fi
else
    echo "[build] Icon already exists, skipping generation."
fi

# ---------------------------------------------------------------------------
# 3. Compile AppleScript into app bundle
# ---------------------------------------------------------------------------
echo "[build] Compiling dxo2photos.applescript ..."
rm -rf "$APP"
osacompile -o "$APP" "$DIR/dxo2photos.applescript"

# ---------------------------------------------------------------------------
# 4. Rename binary and update Info.plist
#    osacompile always names the binary "droplet" regardless of app name.
# ---------------------------------------------------------------------------
echo "[build] Renaming binary ..."
mv "$APP/Contents/MacOS/droplet" "$APP/Contents/MacOS/dxo2photos"
echo "[build] Updating Info.plist ..."
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set  :CFBundleExecutable          dxo2photos"                              "$PLIST"
/usr/libexec/PlistBuddy -c "Set  :CFBundleIconFile             dxo2photos"                              "$PLIST"
/usr/libexec/PlistBuddy -c "Set  :CFBundleIconName             dxo2photos"                              "$PLIST"
/usr/libexec/PlistBuddy -c "Add  :CFBundleIdentifier    string de.wappensc.dxo2photos"                  "$PLIST"
/usr/libexec/PlistBuddy -c "Set  :NSAppleEventsUsageDescription \
    'dxo2photos needs to send Apple Events to Photos to import images.'"                                 "$PLIST"

# ---------------------------------------------------------------------------
# 5. Sign the app so macOS can track Automation permission by bundle identifier.
#    Without a bound Info.plist in the signature, the TCC permission dialog
#    shows an "Edit" button (Script Editor) instead of "Allow / Don't Allow".
# ---------------------------------------------------------------------------
echo "[build] Signing app (ad-hoc) ..."
codesign --force --deep --sign - "$APP"

# ---------------------------------------------------------------------------
# 6. Write output directory into bundle (prompted, default: ~/Pictures/ExportedImages)
# ---------------------------------------------------------------------------
DEFAULT_OUTPUT="$HOME/Pictures/ExportedImages"
if [[ -t 0 ]]; then
    read -r -p "[build] Output directory [$DEFAULT_OUTPUT]: " user_output
    OUTPUT_DIR="${user_output:-$DEFAULT_OUTPUT}"
else
    OUTPUT_DIR="$DEFAULT_OUTPUT"
fi
echo "$OUTPUT_DIR" > "$APP/Contents/Resources/output_dir.txt"
echo "[build] Output directory: $OUTPUT_DIR"

# ---------------------------------------------------------------------------
# 6. Install custom icon
# ---------------------------------------------------------------------------
echo "[build] Installing icon ..."
cp "$DIR/dxo2photos.icns" "$APP/Contents/Resources/dxo2photos.icns"
touch "$APP"   # prompt Finder to refresh icon cache

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "[build] Done: $APP"
echo ""
echo "Optional: create a Finder symlink"
echo "  ln -s \"$APP\" /Applications/dxo2photos.app"
echo ""
echo "Register in DxO PhotoLab: Preferences → External Programs → + → dxo2photos.app"
