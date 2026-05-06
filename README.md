# dxo2photos

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)](https://www.apple.com/macos/)
[![Python](https://img.shields.io/badge/python-3.x-blue)](https://www.python.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A macOS tool that automates the workflow for processing images edited with DxO PhotoLab. It converts star ratings into IPTC keywords, moves or copies images into a defined folder structure, imports them into Apple Photos, and integrates directly into DxO PhotoLab as an external program via a native macOS app bundle.

**Author:** [wappensc](https://github.com/wappensc)

## Prerequisites

- macOS
- Python 3.x (pre-installed on macOS, or `brew install python3`)
- [exiftool](https://exiftool.org): `brew install exiftool`
- Apple Photos installed
- Images exported from DxO PhotoLab with EXIF star ratings

## Installation

Distribution is a complete project directory. A single build script sets up the entire environment.

### 1. Install exiftool

```
brew install exiftool
```

### 2. Clone or copy the project directory

```
git clone https://github.com/wappensc/dxo2photos.git
cd dxo2photos
```

### 3. Run the build script

```
bash build_app.sh
```

This does everything in one step:
- Creates the Python virtual environment (`.venv`) and installs all dependencies
- Generates the app icon
- Compiles `dxo2photos.app`

### 4. Optional: make accessible system-wide

**For DxO PhotoLab and the Finder** — symlink the app into `/Applications`:

```
ln -s "$PWD/dxo2photos.app" /Applications/dxo2photos.app
```

**For command-line use** — symlink the shell script into `/usr/local/bin`:

```
ln -s "$PWD/dxo2photos.sh" /usr/local/bin/dxo2photos
```

Both symlinks point back to the project directory, so all scripts and the Python environment stay in one place. If the project directory moves, run `bash build_app.sh` again to update `dxo2photos.app`.

## DxO PhotoLab Integration

DxO PhotoLab's **External Programs** feature requires a native macOS `.app` bundle — a plain shell script cannot be registered this way, because macOS Launch Services only recognises proper app bundles.

`dxo2photos.app` is compiled by `build_app.sh` from `dxo2photos.applescript`. It receives the exported image paths from DxO via the macOS `on open` handler and forwards them to `dxo2photos.sh` in the project directory. The absolute project path is stored in the bundle at build time, so the app works correctly even when run via a Finder symlink.

### Register in DxO PhotoLab

1. Open DxO PhotoLab → **Preferences** → **External Programs**
2. Click **+** and select `dxo2photos.app` (or its symlink in `/Applications`)
3. Select images in DxO → **Image** → **Open with** → **dxo2photos**

DxO exports the images and passes them to the app, which processes and imports them into Apple Photos automatically.

## Usage

The shell script `dxo2photos.sh` can also be used directly from the command line.

### Process individual files

```
dxo2photos.sh "image1_dxo.jpg" "image2_dxo.jpg"
```

### Scan and process a directory

```
dxo2photos.sh --directory /path/to/DxOExport
```

### Copy instead of move

```
dxo2photos.sh --directory /path/to/DxOExport --copy
```

### Specify a custom target directory

```
dxo2photos.sh --directory /path/to/DxOExport --output-dir ~/Pictures/MyExport
```

### Import an existing directory directly into Photos

```
dxo2photos.sh --import-only /path/to/directory
```

## Configuration

The default target directory and the copy/move behaviour are configured at the top of `dxo2photos.sh`:

```bash
OUTPUT_DIR="$HOME/Pictures/ExportedImages"
COPY_FLAG="--copy"   # set to "" to move instead of copy
```

`OUTPUT_DIR` can also be overridden at runtime with `--output-dir`.

## Features

- Reads EXIF star ratings from DxO images (0–5 stars)
- Converts ratings to IPTC keywords (e.g. 5 stars → `5*`, unrated → `0*`)
- Preserves the original star rating in the EXIF data
- Moves or copies images into a configurable folder structure
- Preserves the relative subdirectory structure of the source directory
- Removes `_dxo` from filenames (e.g. `image_dxo.jpg` → `image.jpg`)
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
