#!/usr/bin/env python3
"""
dxo2photos_testgen - Generates test images for dxo2photos

Creates JPEG test images with EXIF star ratings (0–5) in
TestImages/<random_folder>/ and prints the command to run dxo2photos.py.
"""

import random
from pathlib import Path
from PIL import Image
import piexif

ADJECTIVES = ['sunny', 'rainy', 'golden', 'silent', 'misty', 'crisp']
NOUNS      = ['morning', 'valley', 'forest', 'harbor', 'peak', 'meadow']
NOUNS_WITH_SPACES = ['summer morning', 'green valley', 'autumn forest', 'harbor view']

TEST_CASES = [
    (0, 'unrated'),
    (1, 'one_star'),
    (3, 'three_stars'),
    (5, 'five_stars'),
]


def create_test_images(spaces_in_name=False):
    if spaces_in_name:
        folder_name = f"{random.choice(ADJECTIVES)} {random.choice(NOUNS_WITH_SPACES)}"
    else:
        folder_name = f"{random.choice(ADJECTIVES)}_{random.choice(NOUNS)}"
    base = Path(__file__).parent / 'TestImages' / folder_name
    base.mkdir(parents=True, exist_ok=True)

    for rating, label in TEST_CASES:
        filename = base / f'photo_{label}_openWith.jpg'
        color = (int(255 * rating / 5), 100, 200)
        img = Image.new('RGB', (400, 300), color=color)

        exif_dict = {'0th': {}, 'Exif': {}, 'GPS': {}, '1st': {}, 'thumbnail': None}
        exif_dict['Exif'][piexif.ExifIFD.DateTimeOriginal] = b'2025:03:15 10:20:30'
        if rating > 0:
            exif_dict['0th'][18246] = rating

        exif_bytes = piexif.dump(exif_dict)
        img.save(str(filename), 'jpeg', exif=exif_bytes)
        print(f'Created: {filename}  (rating={rating})')

    print(f'\nAll test images in: TestImages/{folder_name}/')
    print(f'Run now: python dxo2photos.py --directory "TestImages/{folder_name}" --copy')


if __name__ == '__main__':
    create_test_images(spaces_in_name=True)
