# dxo2photos

[![Version](https://img.shields.io/badge/version-2.3.1-blue)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)](https://www.apple.com/macos/)
[![AppleScript](https://img.shields.io/badge/language-AppleScript-orange)](dxo2photos.applescript)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A macOS tool that automates the workflow for processing images edited with DxO PhotoLab. It converts star ratings into IPTC keywords, moves images into a defined folder structure, imports them into Apple Photos, and integrates directly into DxO PhotoLab as an external program via a native macOS app bundle.

**Author:** [wappensc](https://github.com/wappensc-developer)

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
git clone https://github.com/wappensc-developer/dxo2photos-applescript.git
cd dxo2photos-applescript
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

**Root cause of the original Photos import failure:** The problem was not the Python/`osascript` subprocess chain but a missing `CFBundleIdentifier` and an unbound Info.plist in the code signature. Without these, macOS could not track the Automation permission per app and showed "Edit in Script Editor" instead of the expected "Allow / Don't Allow" dialog. The same fix was backported to the Python-based architecture as [v1.0.1](https://github.com/wappensc-developer/dxo2photos-applescript/tree/v1-bugfix). v2 remains the main version as it additionally removes the Python runtime dependency.

## Configuration

Double-click `dxo2photos.app` to open the About dialog. It shows the current settings and offers two buttons:

- **Change output directory…** sets the target root directory. The default is set during `bash build_app.sh`.
- **Star ratings…** sets how DxO star ratings are handled:

| Mode | Star rating in file | Keyword `0*`–`5*` |
|---|---|---|
| Keep star rating and add keyword (default) | kept | written |
| Keep star rating only | kept | not written |
| Keyword only | removed | written |

Settings are stored per user in `~/Library/Application Support/de.wappensc.dxo2photos/config.plist` and can also be set from the command line:

```
defaults write ~/Library/Application\ Support/de.wappensc.dxo2photos/config keepStarRating -bool true
defaults write ~/Library/Application\ Support/de.wappensc.dxo2photos/config writeRatingKeyword -bool false
```

If both are set to `false`, the star rating is kept, so a rating is never lost.

**Note on Apple Photos (macOS 27):** Photos shows star ratings again, but its AppleScript interface offers no rating property (checked on macOS 27.0.1), so dxo2photos cannot set ratings in Photos directly. Whether Photos takes the rating from the file's metadata on import has not been verified. The keyword is the reliable way to carry ratings into Photos (e.g. for smart albums).

## Checking existing images

`dxo2photos_ratings.sh` checks image files for a star rating and a star keyword, and can derive one from the other:

```
./dxo2photos_ratings.sh -r ~/Pictures/ExportedImages            # check only
./dxo2photos_ratings.sh -r --modify ~/Pictures/ExportedImages   # add missing values
./dxo2photos_ratings.sh -r --modify --delete image.jpg folder/  # convert: keep only the new value
./dxo2photos_ratings.sh -r --modify --keep stars folder/         # star rating only in every file
./dxo2photos_ratings.sh -r --modify --keep keyword folder/       # keyword only in every file
./dxo2photos_ratings.sh -r --modify --prefer stars folder/       # resolve conflicts: star rating wins
```

`--delete` leaves `OK` files (rating and keyword both present) unchanged. `--keep stars` or `--keep keyword` ends with only that value in every file: it is written where missing, and the other value is deleted, also in `OK` files. `--keep` cannot be combined with `--delete`.

Conflicts are only changed with `--prefer stars` or `--prefer keyword`, which names the value to trust; the other one is overwritten and the file becomes `OK` (`--keep` then applies as usual). `--prefer stars` fixes a keyword that differs from the rating and several star keywords; `--prefer keyword` fixes a rating that differs from the keyword and differing XMP and EXIF ratings. Other conflicts are reported as not resolved.

| Status | Meaning | With `--modify` |
|---|---|---|
| `OK` | star rating and keyword present and equal | unchanged |
| `STARS` | star rating only | keyword added (`--delete`: rating removed) |
| `KEYWORD` | star keyword only | star rating added (`--delete`: keyword removed) |
| `NONE` | neither | unchanged |
| `CONFLICT` | rating and keyword differ, several star keywords, or XMP and EXIF ratings differ | unchanged, reported as error (`--prefer`: resolved) |
| `INVALID` | rating outside 0–5 (e.g. `-1` = rejected) | unchanged, reported as error |

Directories are scanned for JPEG, TIFF and DNG files; `-r` includes subdirectories. Hidden files and Photos libraries (`*.photoslibrary`) are skipped. Modification dates are preserved; `--backup` keeps each original as `FILE_original`. Run `./dxo2photos_ratings.sh --help` for all options.

## Features

- Reads star ratings from DxO images (0–5 stars; XMP rating preferred over EXIF)
- Converts ratings to IPTC keywords (e.g. 5 stars → `5*`, unrated → `0*`), replacing any outdated star keyword
- Keeps the original star rating in the file (configurable)
- Checks and syncs star ratings and keywords of existing images (`dxo2photos_ratings.sh`)
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
