#!/usr/bin/env python3
"""Prepare local export settings. Never signs, logs in, or uploads."""
import argparse
import json
import pathlib
import plistlib
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--team-id", required=True, help="Your 10-character Apple Developer Team ID")
    parser.add_argument("--output", type=pathlib.Path, required=True, help="New output directory")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Z0-9]{10}", args.team_id):
        parser.error("team-id must contain exactly 10 uppercase letters/digits")
    # Refuse existing directories, including symlinks; preserve earlier preparations.
    if args.output.exists() or args.output.is_symlink():
        parser.error("output already exists; choose a new directory")
    args.output.mkdir(parents=True)
    common = {"teamID": args.team_id, "destination": "export", "signingStyle": "automatic"}
    options = {
        "Mac.ExportOptions.plist": {**common, "method": "developer-id"},
        "iPad.ExportOptions.plist": {
            **common, "method": "app-store-connect", "uploadSymbols": True,
            "manageAppVersionAndBuildNumber": False,
        },
    }
    for name, value in options.items():
        with (args.output / name).open("xb") as output:
            plistlib.dump(value, output, sort_keys=True)
    plan = {
        "version": "1.2.3", "build": "14", "teamID": args.team_id,
        "macOS": {"bundleID": "net.yahaha.fishtank.mac", "channel": "direct-download",
                  "requires": ["Developer ID Application", "notarization", "stapling", "Gatekeeper acceptance"]},
        "iPadOS": {"bundleID": "net.yahaha.fishtank.apple.pad", "channel": "TestFlight",
                   "requires": ["signed device archive", "distribution provisioning", "App Store Connect record", "physical iPad acceptance"]},
        "destination": "local-export-only", "uploaded": False,
        "note": "Export settings do not prove certificate availability, team membership, signing, or acceptance.",
    }
    (args.output / "distribution-plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    print(f"Prepared local export settings: {args.output.resolve()}")
    print("No credentials read; no signing, provisioning updates, notarization, or upload performed.")


if __name__ == "__main__":
    main()
