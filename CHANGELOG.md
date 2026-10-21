# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.1] - 2026-10-21

### Fixed
- `build_app.sh` signed the app before writing `config.plist` and the icon
  into the bundle, so the code signature was invalid ("a sealed resource is
  missing or invalid"). Signing is now the last build step and is verified.

### Changed
- The repository moved to
  `github.com/wappensc-developer/dxo2photos-applescript`. The clone URL and
  links in the README, the specification and the About dialog point to the
  new location and the author account `wappensc-developer`.

## [2.3.0] - 2026-10-21

### Added
- Configurable star rating handling ("Star ratings…" button in the About
  dialog, or `defaults write` keys `keepStarRating` / `writeRatingKeyword`):
  keep the star rating and add the keyword (default, previous behaviour),
  keep the star rating only, or keyword only (star rating removed).
- `dxo2photos_ratings.sh`: command-line tool that checks image files or
  directories for star ratings and star keywords (`0*`–`5*`). `--modify`
  writes the missing value (keyword from rating or rating from keyword),
  `--delete` additionally removes the original value, `--keep stars|keyword`
  leaves only the given value in every file (also in files that have both).
  Conflicting values are reported and only modified with
  `--prefer stars|keyword`, which takes the given value as correct and
  overwrites the other one (e.g. replaces a wrong `0*` keyword with the
  keyword matching the star rating).

### Changed
- The star rating is read from `XMP-xmp:Rating`, falling back to EXIF
  `IFD0:Rating` (previously exiftool's generic `Rating`).
- Writing the star keyword now removes any other star keyword first, so an
  image re-exported with a new rating no longer ends up with two (e.g. `3*`
  and `5*`).
- Ratings outside 0–5 (e.g. `-1` = rejected) are reported in the error dialog
  and leave the metadata unchanged, instead of producing a keyword like `-1*`.

### Fixed
- Images without a capture date (`DateTimeOriginal`, e.g. pictures received
  via messenger apps) got the keyword `0*` although they had a star rating:
  without `-m`, exiftool suppressed the whole output line when one tag was
  missing, so the rating was lost as well. Affected images show up as
  `CONFLICT` in `dxo2photos_ratings.sh` and can be repaired with
  `dxo2photos_ratings.sh --modify --prefer stars`.
- Unrated images did not get their modification date set to the capture
  date, for the same reason: the missing rating tag suppressed
  `DateTimeOriginal` as well.

## [2.2.0] - 2026-05-17

### Added
- Success notification via macOS Notification Center after a clean import
  (sound: Glass; shows file count and album name).
- "Change output directory…" button in the About/run dialog: opens a folder
  chooser and stores the chosen path per-user in
  `~/Library/Application Support/de.wappensc.dxo2photos/config.plist`.

### Changed
- EXIF read operations consolidated: `Rating` and `DateTimeOriginal` are now
  fetched in a single `exiftool -p` call instead of two separate processes,
  reducing exiftool invocations per file from 3 to 2.
- `_openWith` is now stripped only from the filename stem (before the extension)
  rather than being replaced globally, preventing incorrect renames for unlikely
  but possible filenames that contain `_openWith` mid-stem.
- `setExifKeyword` errors are now reported in the end-of-run error dialog
  instead of being silently logged.
- Output directory is now stored per-user in
  `~/Library/Application Support/de.wappensc.dxo2photos/config.plist`
  (via `defaults write`) instead of inside the app bundle, enabling
  system-wide installation without admin rights for configuration changes.
  The bundle retains a `config.plist` as system-wide default set at build time.
- About dialog switched from `display dialog` to `display alert` to show the
  app icon without a two-column layout.

### Fixed
- `build_app.sh`: `NSAppleEventsUsageDescription` now uses `Set`-with-`Add`
  fallback (matching the existing pattern for `CFBundleShortVersionString`) so
  a fresh `osacompile` output no longer aborts the build under `set -euo pipefail`.
- `build_app.sh`: duplicate step label "6." corrected; icon installation is
  now labelled "7.".

## [2.1.0] - 2026-05-12

### Added
- Progress window during image processing: shows current filename, counter
  (`X von N`), and phase (`Verarbeite Bilder…` / `Importiere in Photos…`
  with album name) using native macOS progress properties.
- About dialog (shown on direct launch) now displays version number, author,
  and GitHub repository URL.
- Version is read at runtime from `CFBundleShortVersionString` in Info.plist.

### Changed
- `build_app.sh` sets `CFBundleShortVersionString` in Info.plist.
- `build_app.sh` creates a project-local `.venv` and installs `requirements.txt`
  so icon generation works reproducibly on a fresh checkout without a
  pre-existing `dxo2photos.icns`.
- Added `requirements.txt` declaring `Pillow>=9.0.0` as build-time dependency.

## [2.0.0] - 2026-05-07

### Changed
- Rewrote `dxo2photos.applescript` as a self-contained droplet: all processing
  (EXIF keywords, file move, mtime, Photos import) is now done directly in
  AppleScript without calling Python or a shell script.
- The droplet controls Apple Photos directly via Apple Events, eliminating
  the Python runtime dependency at run time.
- **Note on root cause:** Subsequent testing showed that the original Photos
  import failure was caused by the missing `CFBundleIdentifier` and unbound
  Info.plist in the code signature — not by the Python/`osascript` subprocess
  chain itself. The same `codesign` fix was backported to v1.0.1 and resolved
  the issue there as well. v2 is nevertheless the preferred architecture as it
  removes the Python runtime dependency entirely.
- `build_app.sh` now sets `CFBundleIdentifier` (`de.wappensc.dxo2photos`) and
  re-signs the bundle with `codesign` after plist edits. Without a bound
  Info.plist in the signature, macOS showed an "Edit in Script Editor" button
  instead of the expected "Allow / Don't Allow" Automation permission dialog.
- `build_app.sh` simplified: no Python virtual environment or pip packages
  required at build time; Python is only used optionally for icon generation.

### Fixed
- `_openWith` was not removed from target filenames because `result` is a
  reserved AppleScript keyword; renamed to `theResult` in `replaceText`.

### Removed
- Python runtime dependency (`piexif`, `.venv`) — no longer needed at runtime.
- CLI usage via `dxo2photos.sh` — the app bundle is the only supported interface.

## [1.0.0] - 2026-05-06

### Added
- Convert DxO star ratings (0–5) to IPTC keywords (`0*` – `5*`)
- Move or copy exported images into a configurable folder structure
- Preserve relative subdirectory structure from source directory
- Remove `_openWith` suffix from filenames
- Set file modification date from EXIF `DateTimeOriginal`
- Import images into Apple Photos via AppleScript; create album named after the directory
- Skip duplicate images already present in the Photos library
- CLI options: `--directory`, `--copy`, `--output-dir`, `--import-only`
- Bash wrapper (`dxo2photos.sh`) with automatic Python environment setup on first run
- Symlink-safe script resolution for system-wide installation
