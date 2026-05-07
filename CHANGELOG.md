# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-05-07

### Changed
- Rewrote `dxo2photos.applescript` as a self-contained droplet: all processing
  (EXIF keywords, file move, mtime, Photos import) is now done directly in
  AppleScript without calling Python or a shell script.
- The droplet controls Apple Photos directly via Apple Events. This fixes
  silent import failures when called from DxO PhotoLab, caused by macOS not
  granting Automation permissions to child processes spawned by the previous
  Python/`osascript` chain.
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
