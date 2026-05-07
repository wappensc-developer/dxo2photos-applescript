# Program Specification: dxo2photos

**Version:** 2.0.0 | **Date:** 2026-05-07 | **Author:** [wappensc](https://github.com/wappensc)

## 1. Introduction

### 1.1 Overview
`dxo2photos` is a macOS tool that automates the workflow for processing images edited with DxO PhotoLab. It converts star ratings from DxO into IPTC keywords, moves images into a defined folder structure, imports them into Apple Photos, and integrates directly into DxO PhotoLab as a native external program via a macOS app bundle.

### 1.2 Purpose
Images edited with DxO PhotoLab are to be efficiently imported into Apple Photos. Star ratings from DxO are stored as IPTC keywords. The images are moved into a folder structure for exported images before being imported into Photos. DxO PhotoLab triggers the entire workflow automatically by calling `dxo2photos.app` as an external program.

## 2. Functional Requirements

### 2.1 Input Data
- A list of image files exported from DxO PhotoLab, passed to the app via the macOS `on open` handler.
- The images contain EXIF metadata with star ratings.

### 2.2 Processing
- **Reading star ratings:** Read the star ratings from the EXIF data of the images (EXIF tag 18246) via `exiftool`.
- **Converting to IPTC keywords:** Convert the star ratings into IPTC keywords in the format "0*", "1*", "2*", "3*", "4*", "5*" (e.g. 5 stars → "5*", no rating → "0*"). The original star rating in the EXIF data is preserved. The keyword is removed and re-added to guarantee exactly one occurrence.
- **Moving images:** Move the processed images into a defined folder structure. The target root directory is configured during `build_app.sh` (default: `~/Pictures/ExportedImages`) and stored inside the app bundle. The relative subdirectory structure of the original file (grandparent/parent) is preserved below the target root.
- **Filename adjustment:** Remove the suffix `_openWith` from filenames (e.g. `imagename_openWith.jpg` → `imagename.jpg`).
- **Modification date:** Set the modification date (`mtime`) of the target files to the original capture date from the EXIF field `DateTimeOriginal`, via `touch -t`.

#### Example scenario
- Source: `/Users/armin/Pictures/DxOExport/Session/SubDir/imagename_openWith.jpg`
- Target root: `~/Pictures/ExportedImages`
- Target path after processing: `~/Pictures/ExportedImages/Session/SubDir/imagename.jpg`
- File metadata: original EXIF capture date is set as the modification date of the target file.

### 2.3 Import into Apple Photos
- Import the moved images into Apple Photos directly via Apple Events (no subprocess).
- The app creates an album in Photos named after the target directory (if it does not already exist) and imports all image files into it. Duplicate images already present in the library are not imported again.
- If processed files land in multiple target directories, the common parent directory is imported.

## 3. Non-functional Requirements

### 3.1 Platform
- The program runs on macOS only.
- Uses macOS-specific features: Apple Events for Photos import, `osacompile` for the app bundle.
- On first launch, macOS prompts the user to grant Automation permission for Photos. This permission is stored permanently in System Settings → Privacy & Security → Automation.

### 3.2 User Interface
- No graphical user interface for normal operation.
- `dxo2photos.app` acts as a native macOS droplet that receives files via the `on open` handler.
- On double-click (no files dropped), the app shows an info dialog with the configured output directory.
- Errors during processing are reported in a dialog at the end of the run.

### 3.3 Performance
- Should handle typical DxO export batches efficiently.
- Processing should complete in reasonable time (< 1 second per image for EXIF and file operations; Photos import time depends on library size).

### 3.4 Security
- No sensitive data is processed.
- Images are moved, not deleted; the original is replaced by the target file at a new location.

## 4. Architecture and Design

### 4.1 Components

- **AppleScript source** (`dxo2photos.applescript`): Complete implementation of all processing logic as a self-contained AppleScript droplet. Tracked in version control; compiled into `dxo2photos.app` by `build_app.sh`.

- **Build script** (`build_app.sh`): Run once after installation. Compiles `dxo2photos.applescript` into `dxo2photos.app`, sets the bundle identifier (`de.wappensc.dxo2photos`), signs the bundle ad-hoc, and writes the configured output directory into `Contents/Resources/output_dir.txt`.

- **Icon generator** (`create_icon.py`): Build-time tool. Generates `dxo2photos.icns` at all required macOS icon resolutions using Pillow. Called by `build_app.sh` if the icon file does not already exist. Python is not required at runtime.

- **Test image generator** (`dxo2photos_testgen.py`): Development tool. Creates JPEG test images with EXIF star ratings 0–5 in `TestImages/`.

### 4.2 Why pure AppleScript (no Python subprocess)

The original Photos import failure was traced to a missing `CFBundleIdentifier`
and an unbound Info.plist in the code signature. Without these, macOS cannot
track the Automation permission per app and shows "Edit in Script Editor"
instead of the expected "Allow / Don't Allow" dialog. Applying the `codesign`
fix to the v1 Python-based architecture (released as v1.0.1) resolved the
issue there as well.

v2 was nevertheless kept as the main version for a separate reason: eliminating
the Python runtime dependency (`piexif`, `.venv`) simplifies installation and
removes a class of environment-related failures. The pure-AppleScript droplet
also requires only `exiftool` at runtime, making the tool easier to distribute
and maintain.

### 4.3 Workflow (DxO PhotoLab integration)
1. User selects images in DxO PhotoLab and triggers the external program.
2. DxO exports the images and opens them with `dxo2photos.app` via macOS Launch Services.
3. The app's `on open` handler receives the list of exported file paths.
4. For each file: read EXIF rating, write IPTC keyword, build target path, move file, set mtime.
5. Import all processed files into Photos; create album named after the target directory.

### 4.4 Internal handler structure (`dxo2photos.applescript`)

| Handler | Responsibility |
|---|---|
| `on open` | Main entry point; orchestrates all steps |
| `on run` | Shows info dialog when launched without files |
| `getOutputDir` | Reads output dir from bundle resource |
| `findExiftool` | Locates exiftool binary via PATH |
| `getExifRating` | Reads star rating via exiftool |
| `getExifDatetime` | Reads DateTimeOriginal via exiftool |
| `setExifKeyword` | Writes IPTC keyword via exiftool (remove + add) |
| `buildTargetDir` | Constructs grandparent/parent target path |
| `exifDateToTouchFormat` | Converts EXIF date to `touch -t` format |
| `importToPhotos` | Sends Apple Events to Photos to import files |
| `replaceText` | Removes `_openWith` from filenames |
| `pathParts / parentDirOf / fileNameOf` | Path string utilities |

## 5. Dependencies and Installation

### Runtime dependencies
- `exiftool`: `brew install exiftool`
- macOS with Apple Photos installed

### Build-time dependencies (only needed to run `build_app.sh`)
- `exiftool` (same as above)
- Python 3 + Pillow (only if `dxo2photos.icns` does not exist)

### Installation
```
bash build_app.sh
```
Compiles the app, sets bundle identifier, signs it, and configures the output directory. Run again if the output directory needs to change.

### Optional: system-wide access
```
ln -s "$PWD/dxo2photos.app" /Applications/dxo2photos.app
```

## 6. Test Cases

- Images with 1–5 stars receive the correct keyword (e.g. `3*`).
- Unrated images receive the keyword `0*`.
- Applying the same keyword twice results in exactly one keyword occurrence.
- `_openWith` suffix is correctly removed from filenames.
- Grandparent/parent subdirectory structure is preserved in the target directory.
- Modification date of the target file matches the EXIF `DateTimeOriginal`.
- Directory and file names containing spaces are handled correctly.
- Successful import into Photos with correct album name; duplicates are not imported again.
- On first launch, macOS shows the "Allow / Don't Allow" Automation permission dialog.
- `bash build_app.sh`: app is compiled, bundle identifier set, signed, output dir written.
- DxO PhotoLab integration: exported images are processed and imported into Photos automatically.

## 7. Assumptions and Constraints

- DxO exports images with EXIF star ratings (EXIF tag 18246).
- Apple Photos is installed and configured on the system.
- `exiftool` is installed via Homebrew (`brew install exiftool`).
- Keyword format: "X*" (e.g. 3 stars → "3*", unrated → "0*"). The original star rating is preserved in the EXIF data.
- If the output directory needs to change, `bash build_app.sh` must be run again.
