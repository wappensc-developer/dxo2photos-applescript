# dxo2photos

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)](https://www.apple.com/macos/)
[![Python](https://img.shields.io/badge/python-3.x-blue)](https://www.python.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A Python script for macOS that automates the workflow for processing images edited with DxO PhotoLab. It converts star ratings into IPTC keywords, moves or copies the images into a defined folder structure, and imports them into Apple Photos.

**Author:** [wappensc](https://github.com/wappensc)

## Prerequisites

- macOS
- Python 3.x (pre-installed on macOS, or `brew install python3`)
- [exiftool](https://exiftool.org): `brew install exiftool`
- Apple Photos installed
- Images exported from DxO PhotoLab with EXIF star ratings

## Installation

Only two files are required to distribute and install the program:
- `dxo2photos.sh` — Bash wrapper (entry point)
- `dxo2photos.py` — Python main program

### 1. Install exiftool
```
brew install exiftool
```

### 2. Place the files
Copy both files into any directory, for example:
```
mkdir -p ~/Library/Application\ Support/dxo2photos
cp dxo2photos.sh dxo2photos.py ~/Library/Application\ Support/dxo2photos/
chmod +x ~/Library/Application\ Support/dxo2photos/dxo2photos.sh
```

### 3. Optional: create a symlink for system-wide access
```
ln -s ~/Library/Application\ Support/dxo2photos/dxo2photos.sh /usr/local/bin/dxo2photos
```

The script can then be invoked as `dxo2photos` from any directory.

The Python environment and all dependencies are **set up automatically on the first run** — no further manual steps required.

## Usage

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

The default target directory for exported images is defined as a variable in `dxo2photos.sh`:

```bash
OUTPUT_DIR="$HOME/Pictures/ExportedImages"
```

It can also be overridden at runtime with `--output-dir`.

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

## License

MIT — see [LICENSE](LICENSE) for details.

## Generate test images

```
python dxo2photos_testgen.py
```

Creates test images with ratings 0–5 in `TestImages/<random_folder>/`.
