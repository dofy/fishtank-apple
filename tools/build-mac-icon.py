#!/usr/bin/env python3
"""Package every Mac icon size in a standalone ICNS for system services."""
import pathlib
import shutil
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
source = root / 'Sources/Resources/Assets.xcassets/MacIcon.appiconset'
output = root / 'Sources/Resources/FishtankIcon.icns'
with tempfile.TemporaryDirectory(prefix='fishtank-icon-') as temporary:
    iconset = pathlib.Path(temporary) / 'Fishtank.iconset'
    iconset.mkdir()
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            suffix = '@2x' if scale == 2 else ''
            shutil.copyfile(source / f'icon-{size * scale}.png', iconset / f'icon_{size}x{size}{suffix}.png')
    subprocess.run(['iconutil', '--convert', 'icns', '--output', str(output), str(iconset)], check=True)
print(output)
