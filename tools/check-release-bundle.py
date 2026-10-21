#!/usr/bin/env python3
"""Inspect both built bundles without touching signing accounts or the network."""
import pathlib, plistlib, subprocess, sys
mac, pad = map(pathlib.Path, sys.argv[1:3])
for bundle in (mac, pad):
    macos = (bundle / 'Contents').is_dir()
    root = bundle / 'Contents' if macos else bundle
    resources = root / 'Resources' if macos else root
    info = plistlib.loads((root / 'Info.plist').read_bytes())
    assert info['CFBundleShortVersionString'] == '0.4.0', info
    if macos:
        assert info['CFBundleIdentifier'] == 'net.yahaha.fishtank.mac'
        assert info['CFBundleIconFile'] == 'FishtankIcon.icns'
        assert (resources / info['CFBundleIconFile']).stat().st_size > 50_000
    else:
        assert (resources / 'Assets.car').is_file()
    assert (resources / 'FusionPixel.otf').stat().st_size > 1_000_000
    assert (resources / 'OFL.txt').is_file() and (resources / 'LICENSE').is_file()
    audio = sorted(resources.glob('*.wav'))
    assert len(audio) == 20, len(audio)
    privacy = plistlib.loads((resources / 'PrivacyInfo.xcprivacy').read_bytes())
    assert privacy['NSPrivacyTracking'] is False
    assert privacy['NSPrivacyCollectedDataTypes'] == []
    if macos:
        assert info['LSUIElement'] is True
        arches = subprocess.check_output(['lipo', '-archs', str(root / 'MacOS' / info['CFBundleExecutable'])], text=True).split()
        assert set(arches) == {'arm64', 'x86_64'}, arches
    else:
        assert info['UIDeviceFamily'] == [2]
        assert len(info['UISupportedInterfaceOrientations']) == 4
        assert info['ITSAppUsesNonExemptEncryption'] is False
    print(f'PASS {bundle.name}: version, icon, font, licenses, privacy, 20 WAVs and platform metadata')
