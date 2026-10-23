#!/usr/bin/env python3
"""Inspect both built bundles without touching signing accounts or the network."""
import pathlib, plistlib, subprocess, sys, hashlib, struct, json
mac, pad = map(pathlib.Path, sys.argv[1:3])
for bundle in (mac, pad):
    macos = (bundle / 'Contents').is_dir()
    root = bundle / 'Contents' if macos else bundle
    resources = root / 'Resources' if macos else root
    info = plistlib.loads((root / 'Info.plist').read_bytes())
    assert info['CFBundleShortVersionString'] == '1.4.0', info
    assert info['CFBundleVersion'] == '20', info
    if macos:
        assert info['CFBundleIdentifier'] == 'net.yahaha.fishtank.mac'
        assert info['CFBundleIconFile'] == 'FishtankIcon.icns'
        assert (resources / info['CFBundleIconFile']).stat().st_size > 50_000
        variants = sorted(resources.glob('FishtankIcon-*.icns'))
        catalog = json.loads((resources / 'AppIconCatalog.json').read_text())
        expected = {entry['resourceName'] for entry in catalog if entry['id'] != 'classic'}
        assert {icon.stem for icon in variants} == expected
        assert len({entry['speciesID'] for entry in catalog if not entry['secondarySpeciesID']}) == len(catalog) - 1
        assert len(catalog) == 33
        assert {'lanternangler', 'glassangel', 'starnautilus'}.issubset({entry['speciesID'] for entry in catalog})
        fingerprints = set()
        for icon in variants:
            data = icon.read_bytes()
            assert data[:4] == b'icns' and struct.unpack('>I', data[4:8])[0] == len(data)
            preview = icon.with_suffix('.png').read_bytes()
            assert preview[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', preview[16:24]) == (512, 512)
            fingerprints.add(hashlib.sha256(preview).digest())
        assert len(fingerprints) == len(expected), 'Duplicate icon designs'

    else:
        assert (resources / 'Assets.car').is_file()
    for sprite in ['lanternangler', 'glassangel', 'starnautilus', 'medal-secret-encounter', 'medal-secret-trio']:
        data = (resources / 'PixelSprites' / (sprite + '.png')).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II', data[16:24]) == ((24, 32) if sprite.startswith('medal-') else (64, 48))
    assert info['CFBundleDevelopmentRegion'] == 'en'
    assert set(info['CFBundleLocalizations']) == {'en', 'zh-Hans', 'zh-Hant', 'ja'}
    for face in ['FusionPixel', 'FusionPixel-Latin', 'FusionPixel-Traditional', 'FusionPixel-Japanese']:
        assert (resources / (face + '.otf')).stat().st_size > 1_000_000
    assert (resources / 'DepartureMono-Regular.otf').stat().st_size > 10_000
    assert (resources / 'DepartureMono-OFL.txt').is_file()
    catalogs = [json.loads((resources / (language + '.json')).read_text()) for language in ['en', 'zh-Hans', 'zh-Hant', 'ja']]
    assert len(catalogs[0]) >= 538 and all(set(catalog) == set(catalogs[0]) for catalog in catalogs)
    assert (resources / 'OFL.txt').is_file() and (resources / 'LICENSE').is_file()
    audio = sorted(resources.glob('*.wav'))
    assert len(audio) == 23, len(audio)
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
    print(f'PASS {bundle.name}: version, icon, font, licenses, privacy, 23 WAVs and platform metadata')
