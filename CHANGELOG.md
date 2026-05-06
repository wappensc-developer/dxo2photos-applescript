# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
