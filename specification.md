# Program Specification: dxo2photos

**Version:** 1.0.0 | **Date:** 2026-05-06 | **Author:** [wappensc](https://github.com/wappensc)

## 1. Introduction

### 1.1 Overview
`dxo2photos` is a macOS tool that automates the workflow for processing images edited with DxO PhotoLab. It converts star ratings from DxO into IPTC keywords, moves or copies images into a defined folder structure, imports them into Apple Photos, and integrates directly into DxO PhotoLab as a native external program via a macOS app bundle.

### 1.2 Purpose
Images edited with DxO PhotoLab are to be efficiently imported into Apple Photos. Star ratings from DxO are stored as IPTC keywords. The images are moved (or copied) into a folder structure for exported images before being imported into Photos. DxO PhotoLab can trigger the entire workflow automatically by calling `dxo2photos.app` as an external program.

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
- Uses macOS-specific features for the Photos import (AppleScript via `osascript`) and for the DxO integration (app bundle via `osacompile`).

### 3.2 User Interface
- No graphical user interface required for normal operation.
- For DxO PhotoLab integration, `dxo2photos.app` acts as a native macOS application that receives files via the `on open` handler.
- For command-line use, the entry point is `dxo2photos.sh` with the following options:

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

- **Build script** (`build_app.sh`): Run once after installation. Sets up the Python virtual environment, installs dependencies, generates the app icon, and compiles `dxo2photos.app`. Writes the absolute project directory path into the app bundle so the app can locate its scripts at runtime.

- **AppleScript application** (`dxo2photos.app`): Compiled from `dxo2photos.applescript` by `build_app.sh`. Registered in DxO PhotoLab as an external program. Receives exported image paths from DxO via the macOS `on open` handler and delegates to `dxo2photos.sh`. Reads the project directory path from `Contents/Resources/project_path.txt` — this allows the app to be symlinked (e.g. into `/Applications`) while scripts and the Python environment remain in the project directory.

- **AppleScript source** (`dxo2photos.applescript`): Human-readable source for `dxo2photos.app`, tracked in version control.

- **Icon generator** (`create_icon.py`): Generates `dxo2photos.icns` at all required macOS icon resolutions using Pillow. Called by `build_app.sh`.

- **Bash wrapper** (`dxo2photos.sh`): Runtime entry point for command-line use. Resolves its own location via symlinks, verifies that the Python environment exists, and invokes `dxo2photos.py`. Configures `OUTPUT_DIR` and `COPY_FLAG`.

- **Python main program** (`dxo2photos.py`): Contains all processing logic in a single file:
  - *EXIF handling*: reads star ratings and EXIF date; writes IPTC keywords via `exiftool`
  - *File management*: moves or copies images, removes `_dxo`, sets modification date
  - *Photos import*: integration with Apple Photos via AppleScript
  - *CLI*: processes all command-line arguments

### 4.2 Workflow (DxO PhotoLab integration)
1. User selects images in DxO PhotoLab and triggers the external program.
2. DxO exports the images and opens them with `dxo2photos.app`.
3. The app's `on open` handler reads `project_path.txt` to locate `dxo2photos.sh`.
4. `dxo2photos.sh` is called with the exported image paths.
5. Processing continues as in the normal workflow (steps 2–6 below).

### 4.3 Workflow (normal mode)
1. `dxo2photos.sh` verifies the Python environment and calls `dxo2photos.py`.
2. Input: list of image files (directly or via `--directory`).
3. For each image: read EXIF rating, write IPTC keyword.
4. Move or copy images, remove `_dxo` from filenames.
5. Set modification date in target directory from EXIF.
6. Import target directory into Photos, create album named after the directory.

### 4.4 Workflow (--import-only)
1. Input: path to an existing directory.
2. For each image file in the directory: set modification date from EXIF.
3. Import directory into Photos, create album named after the directory.

## 5. Dependencies and Installation

### System dependencies (install once manually)
- `exiftool`: `brew install exiftool`
- Python 3.x: pre-installed on macOS or `brew install python3`

### Python packages (installed automatically by `build_app.sh`)
- `piexif>=1.1.3`: EXIF reading (rating, DateTimeOriginal)
- `Pillow>=9.0.0`: icon generation

### Distribution
The complete project directory is distributed. All required files are included; no separate packaging step is needed.

### Installation
```
bash build_app.sh
```
This single command sets up the Python environment, generates the icon, and compiles the app. It must be run once after cloning or copying the project directory.

### Optional: Finder / DxO access via symlink
```
ln -s /path/to/dxo2photos/dxo2photos.app /Applications/dxo2photos.app
```

### Optional: command-line access via symlink
```
ln -s /path/to/dxo2photos/dxo2photos.sh /usr/local/bin/dxo2photos
```

Both symlinks point back to the project directory. If the project directory is moved, run `bash build_app.sh` again.

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
- `bash build_app.sh`: Python environment is created, icon generated, `dxo2photos.app` compiled.
- Invocation via symlink from `/Applications`: app correctly resolves the project directory via `project_path.txt`.
- DxO PhotoLab integration: exported images are processed automatically when the external program is triggered.

## 7. Assumptions and Constraints

- DxO exports images with EXIF star ratings (EXIF tag 18246).
- Apple Photos is installed and configured on the system.
- `exiftool` is installed via Homebrew (`brew install exiftool`).
- Keyword format: "X*" (e.g. 3 stars → "3*", unrated → "0*"). The original star rating is preserved in the EXIF data.
- The source directory contains a marker directory (`DxOExport` or `TestImages`) used to determine the relative subdirectory structure.
- If the project directory is moved after the initial build, `build_app.sh` must be run again to update the path stored in the app bundle.
