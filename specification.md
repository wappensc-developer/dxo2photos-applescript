# Program Specification: dxo2photos

**Version:** 1.0.0 | **Date:** 2026-05-06 | **Author:** [wappensc](https://github.com/wappensc)

## 1. Introduction

### 1.1 Overview
`dxo2photos` is a Python script for macOS that automates the workflow for processing images edited with DxO PhotoLab. It converts star ratings from DxO into IPTC keywords, moves or copies the images into a defined folder structure, and imports them into Apple Photos.

### 1.2 Purpose
Images edited with DxO PhotoLab are to be efficiently imported into Apple Photos. Star ratings from DxO are stored as IPTC keywords. The images are moved (or copied) into a folder structure for exported images before being imported into Photos.

## 2. Functional Requirements

### 2.1 Input Data
- A list of image files exported from DxO PhotoLab.
- The images contain EXIF metadata with star ratings.

### 2.2 Processing
- **Reading star ratings:** Read the star ratings from the EXIF data of the images (EXIF tag 18246).
- **Converting to IPTC keywords:** Convert the star ratings into IPTC keywords in the format "0*", "1*", "2*", "3*", "4*", "5*" (e.g. 5 stars → "5*", no rating → "0*"). The original star rating in the EXIF data is preserved.
- **Writing keywords:** Add the keyword as an IPTC keyword to the image file without overwriting existing keywords. Writing is done via `exiftool`.
- **Moving or copying images:** Move or copy the processed images into a defined folder structure for exported images. The target directory is configured as `OUTPUT_DIR` in `dxo2photos.sh` (default: `~/Pictures/ExportedImages`) and can be overridden via `--output-dir`. The relative subdirectory structure of the original file (e.g. `a/b`) is preserved below the target directory.
- **Filename adjustment:** Remove the suffix `_dxo` from filenames in the target directory while preserving the rest of the name and file type (e.g. `imagename_dxo.jpg` → `imagename.jpg`).
- **Modification date:** Set the modification date (`mtime`) of the final files in the target directory to the original capture date of the image, based on the EXIF field `DateTimeOriginal`. This is done via `os.utime()` (pure Python). This step takes place in the target directory before the images are imported into Photos.

#### Example scenario
- Source: `/Users/armin/Pictures/DxOExport/a/b/imagename_dxo.jpg`
- Target root: `~/Pictures/ExportedImages`
- Target path after processing: `~/Pictures/ExportedImages/a/b/imagename.jpg`
- File metadata: original EXIF capture date is set as the modification date of the target file.

### 2.3 Import into Apple Photos
- Import the moved or copied images into Apple Photos.
- The import is triggered from Python via macOS AppleScript using `osascript` from the Python standard library module `subprocess`.
- The AppleScript creates an album in Photos named after the imported directory (if it does not already exist) and imports all image files from that directory into the album. Duplicate images already present in the library are not imported again. Example:
  ```
  tell application "Photos"
      set theAlbum to make new album named "<directory name>"
      import {POSIX file "<path1>", POSIX file "<path2>"} into theAlbum skip check duplicates false
  end tell
  ```
- Python waits for the AppleScript call to finish and checks the return code.
- Logs success or failure of the import and outputs a meaningful message on error.
- The import from Python is kept as simple as possible: no GUI, command-line integration only via `osascript`.

## 3. Non-functional Requirements

### 3.1 Platform
- The program runs on macOS only.
- Uses macOS-specific features for the Photos import (AppleScript via `osascript`).

### 3.2 User Interface
- No graphical user interface required.
- The entry point is `dxo2photos.sh`; the program runs as a command-line tool with the following options:

| Option | Short | Description |
|--------|-------|-------------|
| `<file> [<file> ...]` | | Process individual image files |
| `--directory DIRECTORY` | `-d` | Scan and process all `*_dxo.*` files in a directory |
| `--copy` | | Copy images to the target directory instead of moving |
| `--output-dir DIRECTORY` | `-o` | Override the target directory (default: `OUTPUT_DIR` from `dxo2photos.sh`) |
| `--import-only DIRECTORY` | `-i` | Import an existing directory directly into Photos (sets modification date from EXIF first) |

### 3.3 Performance
- Should handle large numbers of images efficiently.
- Processing should complete in reasonable time (e.g. < 1 second per image).

### 3.4 Security
- No sensitive data is processed.
- Images are only read and modified; no deletion without confirmation.

## 4. Architecture and Design

### 4.1 Components
- **Bash wrapper** (`dxo2photos.sh`): Entry point; automatically sets up the Python environment on the first run; configures `OUTPUT_DIR`; supports invocation via symlink.
- **Python main program** (`dxo2photos.py`): Contains all program logic in a single file:
  - *Configuration*: `ROOT_DIR` as fallback target directory
  - *EXIF handling*: reads star ratings and EXIF date; writes IPTC keywords via `exiftool`
  - *File management*: moves or copies images, removes `_dxo`, sets modification date
  - *Photos import*: integration with Apple Photos via AppleScript
  - *CLI*: processes all command-line arguments

### 4.2 Workflow (normal mode)
1. `dxo2photos.sh` checks/sets up the Python environment and calls `dxo2photos.py`.
2. Input: list of image files (directly or via `--directory`).
3. For each image: read EXIF rating, write IPTC keyword.
4. Move or copy images, remove `_dxo` from filenames.
5. Set modification date in target directory from EXIF.
6. Import target directory into Photos, create album named after the directory.

### 4.3 Workflow (--import-only)
1. Input: path to an existing directory.
2. For each image file in the directory: set modification date from EXIF.
3. Import directory into Photos, create album named after the directory.

## 5. Dependencies and Installation

### System dependencies (install once manually)
- `exiftool`: `brew install exiftool`
- Python 3.x: pre-installed on macOS or `brew install python3`

### Python packages (installed automatically by `dxo2photos.sh`)
- `piexif>=1.1.3`: EXIF reading (rating, DateTimeOriginal)

### Files to distribute
Only two files are required to distribute the program:
- `dxo2photos.sh` — Bash wrapper and entry point
- `dxo2photos.py` — Python main program

### Installation via symlink
For system-wide access, a symlink can be created in `/usr/local/bin`:
```
ln -s /path/to/dxo2photos.sh /usr/local/bin/dxo2photos
```
The script automatically resolves its real location even when called through a symlink.

## 6. Test Cases

- Images with 1–5 stars receive the correct keyword (e.g. "3*").
- Unrated images receive the keyword "0*".
- Faulty images are skipped with a warning.
- `_dxo` suffix is correctly removed from filenames.
- Relative subdirectory structure is preserved in the target directory.
- Modification date in the target directory matches the EXIF date.
- Directory names containing spaces are handled correctly.
- Successful import into Photos with correct album name; duplicates are not imported again.
- `--copy`: source file is preserved, target file is created.
- `--import-only`: directory is imported directly, modification dates are set beforehand.
- Invocation via symlink: script correctly locates `dxo2photos.py`.
- First run without `.venv`: Python environment is set up automatically.

## 7. Assumptions and Constraints

- DxO exports images with EXIF star ratings (EXIF tag 18246).
- Apple Photos is installed and configured on the system.
- `exiftool` is installed via Homebrew (`brew install exiftool`).
- Keyword format: "X*" (e.g. 3 stars → "3*", unrated → "0*"). The original star rating is preserved in the EXIF data.
- The source directory contains a marker directory (`DxOExport` or `TestImages`) used to determine the relative subdirectory structure.
