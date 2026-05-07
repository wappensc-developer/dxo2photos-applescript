# dxo2photos

[![Version](https://img.shields.io/badge/version-2.0.0-blue)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)](https://www.apple.com/macos/)
[![AppleScript](https://img.shields.io/badge/language-AppleScript-orange)](dxo2photos.applescript)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A macOS tool that automates the workflow for processing images edited with DxO PhotoLab. It converts star ratings into IPTC keywords, moves images into a defined folder structure, imports them into Apple Photos, and integrates directly into DxO PhotoLab as an external program via a native macOS app bundle.

**Author:** [wappensc](https://github.com/wappensc)

## Prerequisites

- macOS
- [exiftool](https://exiftool.org): `brew install exiftool`
- Apple Photos installed
- Images exported from DxO PhotoLab with EXIF star ratings

## Installation

### 1. Install exiftool

```
brew install exiftool
```

### 2. Clone the project directory

```
git clone https://github.com/wappensc/dxo2photos.git
cd dxo2photos
```

### 3. Run the build script

```
bash build_app.sh
```

This compiles `dxo2photos.applescript` into `dxo2photos.app` and prompts for the output directory (default: `~/Pictures/ExportedImages`).

### 4. Optional: make accessible system-wide

```
ln -s "$PWD/dxo2photos.app" /Applications/dxo2photos.app
```

## DxO PhotoLab Integration

### Register dxo2photos.app

1. Open DxO PhotoLab → **Preferences** → **External Programs**
2. Click **+** and select `dxo2photos.app` (or its symlink in `/Applications`)
3. Select images in DxO → **Image** → **Open with** → **dxo2photos**

DxO exports the images and passes them to the app, which processes and imports them into Apple Photos automatically.

### First-time permission grant

The first time dxo2photos runs after installation, macOS will show a dialog:

> **"dxo2photos" wants access to control "Photos".**

Click **Allow**. This grants the Automation permission that Photos import requires. The permission is stored permanently in System Settings → Privacy & Security → Automation and does not need to be granted again.

If the dialog does not appear and imports are silently skipped, open System Settings → Privacy & Security → Automation, find `dxo2photos`, and enable the toggle next to Photos.

### Architecture

`dxo2photos.app` is a compiled AppleScript droplet, signed ad-hoc with bundle identifier `de.wappensc.dxo2photos`. The droplet's process receives the files from DxO PhotoLab via the macOS `on open` handler and controls Apple Photos directly via Apple Events.

EXIF metadata operations (reading star ratings, writing keywords, setting modification dates) are performed via `exiftool` through `do shell script`.

**Root cause of the original Photos import failure:** The problem was not the Python/`osascript` subprocess chain but a missing `CFBundleIdentifier` and an unbound Info.plist in the code signature. Without these, macOS could not track the Automation permission per app and showed "Edit in Script Editor" instead of the expected "Allow / Don't Allow" dialog. The same fix was backported to the Python-based architecture as [v1.0.1](https://github.com/wappensc/dxo2photos/tree/v1-bugfix). v2 remains the main version as it additionally removes the Python runtime dependency.

## Configuration

The output directory is set once during `bash build_app.sh` and stored inside the app bundle (`Contents/Resources/output_dir.txt`). To change it, run `bash build_app.sh` again.

## Features

- Reads EXIF star ratings from DxO images (0–5 stars)
- Converts ratings to IPTC keywords (e.g. 5 stars → `5*`, unrated → `0*`)
- Preserves the original star rating in the EXIF data
- Moves images into a configurable folder structure
- Preserves the relative subdirectory structure of the source directory
- Removes `_openWith` from filenames (e.g. `image_openWith.jpg` → `image.jpg`)
- Sets the modification date to the EXIF capture date
- Imports images into Apple Photos and creates an album named after the directory
- Skips duplicate images already present in the Photos library
- Integrates into DxO PhotoLab as a native macOS external program

## License

MIT — see [LICENSE](LICENSE) for details.

## Generate test images

```
python dxo2photos_testgen.py
```

Creates test images with ratings 0–5 in `TestImages/<random_folder>/`.
