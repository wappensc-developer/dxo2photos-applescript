#!/usr/bin/env bash
# build_app.sh — One-time build script for dxo2photos
#
# Sets up the Python environment, generates the app icon, and compiles
# dxo2photos.app. Run this once after cloning the project:
#
#   bash build_app.sh
#
# Afterwards, optionally create a symlink so the app appears in the Finder:
#
#   ln -s "$PWD/dxo2photos.app" /Applications/dxo2photos.app
#
# To register the app in DxO PhotoLab:
#   Preferences → External Programs → + → select dxo2photos.app

set -euo pipefail

# Ensure Homebrew tools are on the PATH (Apple Silicon: /opt/homebrew, Intel: /usr/local)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$DIR/dxo2photos.app"
VENV="$DIR/.venv"

# ---------------------------------------------------------------------------
# 1. Check prerequisites
# ---------------------------------------------------------------------------
echo "[build] Checking prerequisites ..."

if ! command -v exiftool &>/dev/null; then
    echo "[build] Error: 'exiftool' is not installed." >&2
    echo "[build] Please install it with: brew install exiftool" >&2
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "[build] Error: 'python3' not found." >&2
    echo "[build] Please install Python 3: brew install python3" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Create Python virtual environment and install packages
# ---------------------------------------------------------------------------
if [[ ! -d "$VENV" ]]; then
    echo "[build] Creating Python virtual environment ..."
    python3 -m venv "$VENV"
fi

echo "[build] Installing Python packages ..."
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet "Pillow>=9.0.0" "piexif>=1.1.3"

# ---------------------------------------------------------------------------
# 3. Generate app icon
# ---------------------------------------------------------------------------
echo "[build] Generating icon ..."
"$VENV/bin/python" "$DIR/create_icon.py"

# ---------------------------------------------------------------------------
# 4. Compile AppleScript into app bundle
# ---------------------------------------------------------------------------
echo "[build] Compiling dxo2photos.applescript ..."
rm -rf "$APP"
osacompile -o "$APP" "$DIR/dxo2photos.applescript"

# ---------------------------------------------------------------------------
# 5. Rename binary and icon from the osacompile default "droplet" to "dxo2photos"
# ---------------------------------------------------------------------------
echo "[build] Renaming bundle artefacts ..."
mv "$APP/Contents/MacOS/droplet" "$APP/Contents/MacOS/dxo2photos"
mv "$APP/Contents/Resources/droplet.icns" "$APP/Contents/Resources/dxo2photos.icns"
mv "$APP/Contents/Resources/droplet.rsrc" "$APP/Contents/Resources/dxo2photos.rsrc"
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable dxo2photos" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile   dxo2photos" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconName   dxo2photos" "$PLIST"

# ---------------------------------------------------------------------------
# 6. Write project directory path into bundle
#    The AppleScript reads this to locate dxo2photos.sh at runtime,
#    even when the app is run via a symlink from /Applications.
# ---------------------------------------------------------------------------
echo "$DIR" > "$APP/Contents/Resources/project_path.txt"

# ---------------------------------------------------------------------------
# 7. Install custom icon
# ---------------------------------------------------------------------------
echo "[build] Installing icon ..."
cp "$DIR/dxo2photos.icns" "$APP/Contents/Resources/dxo2photos.icns"
touch "$APP"   # prompt Finder to refresh its icon cache

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
