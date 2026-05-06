#!/usr/bin/env python3
"""
dxo2photos - Automated processing and import of DxO PhotoLab images into Apple Photos

This script processes images exported from DxO PhotoLab:
- Converts star ratings to IPTC keywords (e.g. "3*", "0*" for unrated)
- Moves or copies images into a defined folder structure
- Sets the modification date from EXIF data
- Imports images into Apple Photos (into an album named after the directory)

Usage:
    python dxo2photos.py <image_file1> [<image_file2> ...]
    python dxo2photos.py --directory <directory> [--copy]
    python dxo2photos.py --import-only <directory>
"""

__version__ = '1.0.0'
__author__  = 'wappensc'
__license__ = 'MIT'

import argparse
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import piexif

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Root directory for exported images — adjust as needed
ROOT_DIR = Path.home() / "Pictures" / "ExportedImages"
ROOT_DIR.mkdir(parents=True, exist_ok=True)

IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.tif', '.tiff', '.png', '.heic', '.heif'}

# ---------------------------------------------------------------------------
# EXIF handling
# ---------------------------------------------------------------------------

def get_exif_rating(img_path):
    """Reads the star rating from EXIF data."""
    try:
        exif_dict = piexif.load(str(img_path))
        if '0th' in exif_dict:
            return exif_dict['0th'].get(18246, 0)  # 18246 is the Rating tag
        return 0
    except Exception as e:
        print(f"Error reading EXIF rating for {img_path}: {e}")
        return 0


def get_exif_datetime(img_path):
    """Reads the original capture date from EXIF data."""
    try:
        exif_dict = piexif.load(str(img_path))
        if 'Exif' in exif_dict:
            datetime_str = exif_dict['Exif'].get(piexif.ExifIFD.DateTimeOriginal)
            if datetime_str:
                return datetime_str.decode('utf-8')
        return None
    except Exception as e:
        print(f"Error reading EXIF date for {img_path}: {e}")
        return None


def set_exif_keywords(img_path, keyword):
    """Adds an IPTC keyword to the image file via exiftool without overwriting existing keywords."""
    try:
        result = subprocess.run(
            ['exiftool', '-overwrite_original', f'-Keywords+={keyword}', str(img_path)],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            print(f"Keyword '{keyword}' added to {img_path}.")
        else:
            print(f"Error setting keyword for {img_path}: {result.stderr.strip()}")
    except FileNotFoundError:
        print("Error: exiftool not found. Please install it: brew install exiftool")
    except Exception as e:
        print(f"Error setting keyword for {img_path}: {e}")


def process_image_exif(img_path):
    """Reads the star rating and writes the corresponding IPTC keyword."""
    rating = get_exif_rating(img_path)
    set_exif_keywords(img_path, f"{rating}*")

# ---------------------------------------------------------------------------
# File management
# ---------------------------------------------------------------------------

def apply_exif_dates(file_path):
    """Sets the modification date of a file from its EXIF data."""
    exif_date = get_exif_datetime(file_path)
    if exif_date:
        try:
            timestamp = datetime.strptime(exif_date, '%Y:%m:%d %H:%M:%S').timestamp()
            os.utime(str(file_path), (timestamp, timestamp))
        except Exception as e:
            print(f"Error setting date for {file_path}: {e}")


def move_and_rename_image(source_path, copy=False, root_dir=None):
    """Moves or copies the image, renames it and sets the modification date."""
    source_path = Path(source_path)
    effective_root = Path(root_dir) if root_dir else ROOT_DIR
    try:
        exif_date = get_exif_datetime(source_path)

        # Determine relative path by searching for a known marker directory
        parts = source_path.parts
        relative_parts = None
        for marker in ['DxOExport', 'TestImages']:
            if marker in parts:
                relative_parts = parts[parts.index(marker) + 1:]
                break
        if not relative_parts:
            try:
                relative_parts = source_path.relative_to(Path.cwd()).parts
            except ValueError:
                relative_parts = (source_path.name,)

        target_dir = effective_root / Path(*relative_parts[:-1]) if len(relative_parts) > 1 else effective_root
        target_dir.mkdir(parents=True, exist_ok=True)

        target_path = target_dir / source_path.name.replace('_openWith', '')

        if copy:
            shutil.copy2(str(source_path), str(target_path))
        else:
            shutil.move(str(source_path), str(target_path))

        # Set modification date from EXIF in the target directory (before Photos import)
        if exif_date:
            try:
                timestamp = datetime.strptime(exif_date, '%Y:%m:%d %H:%M:%S').timestamp()
                os.utime(str(target_path), (timestamp, timestamp))
            except Exception as e:
                print(f"Error setting date for {target_path}: {e}")

        return target_path

    except Exception as e:
        raise Exception(f"Error processing {source_path}: {e}")

# ---------------------------------------------------------------------------
# Apple Photos import
# ---------------------------------------------------------------------------

def import_to_photos(directory):
    """Imports all images from a directory into Photos and creates an album named after the directory."""
    if not directory:
        return

    dir_path = Path(directory) if not isinstance(directory, Path) else directory
    if not dir_path.exists():
        print(f"Error: directory {dir_path} does not exist.")
        return

    image_files = sorted(
        f for f in dir_path.rglob('*')
        if f.is_file() and f.suffix.lower() in IMAGE_EXTENSIONS
    )
    if not image_files:
        print(f"No image files found in {dir_path}.")
        return

    album_name = dir_path.name
    escaped_album = album_name.replace('"', '\\"')
    posix_list = ', '.join(f'POSIX file "{f}"' for f in image_files)

    applescript = f'''tell application "Photos"
    activate
    if not (exists album named "{escaped_album}") then
        set theAlbum to make new album named "{escaped_album}"
    else
        set theAlbum to album named "{escaped_album}"
    end if
    import {{{posix_list}}} into theAlbum skip check duplicates false
end tell'''

    try:
        result = subprocess.run(['osascript', '-e', applescript],
                                capture_output=True, text=True, timeout=300)
        if result.returncode == 0:
            print(f"Photos import into album '{album_name}' successful: {len(image_files)} images")
        else:
            print(f"Error during Photos import: {result.stderr.strip()}")
            if result.stdout:
                print(f"Photos output: {result.stdout.strip()}")
    except subprocess.TimeoutExpired:
        print("Photos import timed out.")
    except Exception as e:
        print(f"Error running AppleScript: {e}")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description='Process DxO images for Apple Photos import')
    parser.add_argument('files', nargs='*', help='Image files to process')
    parser.add_argument('--directory', '-d', metavar='DIRECTORY',
                        help='Scan and process all *_openWith.* files in a directory')
    parser.add_argument('--copy', action='store_true',
                        help='Copy images to target directory instead of moving')
    parser.add_argument('--import-only', '-i', metavar='DIRECTORY',
                        help='Import an existing directory directly into Photos (sets modification date from EXIF first)')
    parser.add_argument('--output-dir', '-o', metavar='DIRECTORY',
                        help=f'Override target directory for exported images (default: {ROOT_DIR})')
    args = parser.parse_args()

    # --- Mode: import only ---
    if args.import_only:
        import_dir = Path(args.import_only)
        if not import_dir.exists():
            print(f"Error: directory {import_dir} does not exist.")
            sys.exit(1)
        print(f"Setting modification dates from EXIF in '{import_dir}'...")
        for img_path in sorted(import_dir.rglob('*')):
            if img_path.is_file() and img_path.suffix.lower() in IMAGE_EXTENSIONS:
                apply_exif_dates(img_path)
        print(f"Importing directory '{import_dir.name}' into Photos...")
        import_to_photos(import_dir)
        print("Import complete.")
        return

    # --- Mode: process and import ---
    if args.directory:
        dir_path = Path(args.directory)
        if not dir_path.exists():
            print(f"Directory {args.directory} does not exist.")
            sys.exit(1)
        image_files = list(dir_path.rglob('*_openWith.*'))
    else:
        image_files = [Path(f) for f in args.files if Path(f).exists()]

    if not image_files:
        print("No image files found.")
        sys.exit(1)

    action = "Copying" if args.copy else "Moving"
    print(f"Processing {len(image_files)} images ({action.lower()} to target directory)...")

    processed_files = []
    target_dirs = set()

    for img_path in image_files:
        try:
            print(f"Processing: {img_path}")
            process_image_exif(img_path)
            new_path = move_and_rename_image(img_path, copy=args.copy, root_dir=args.output_dir)
            processed_files.append(new_path)
            target_dirs.add(new_path.parent)
            print(f"  -> {new_path}")
        except Exception as e:
            print(f"Error processing {img_path}: {e}")

    if not processed_files:
        print("No images processed successfully.")
        return

    target_dir = list(target_dirs)[0] if len(target_dirs) == 1 else sorted(target_dirs)[0].parent
    print(f"\nImporting '{target_dir.name}' into Photos...")
    import_to_photos(target_dir)
    print("Import complete.")


if __name__ == '__main__':
    main()
