#!/bin/bash
# Local candidate packaging only. No Developer ID signing, notarization or upload.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -gt 1 || "${1:-}" == --* ]]; then
  printf 'Usage: %s [output-directory]\n' "$0" >&2
  exit 1
fi
candidate_dir="${1:-build/distribution/1.2.3-candidate}"
if [[ $# -eq 1 && -e "$candidate_dir" ]]; then
  printf 'Choose a new output directory; refusing to overwrite: %s\n' "$candidate_dir" >&2
  exit 1
fi
# NSWorkspace reads only application metadata; it does not activate any app.
running_pid="$(swift - "$candidate_dir/Fishtank.app" <<'SWIFT'
import AppKit
let target = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
for app in NSWorkspace.shared.runningApplications {
    if app.bundleURL?.standardizedFileURL.resolvingSymlinksInPath() == target {
        print(app.processIdentifier)
    }
}
SWIFT
)"
if [[ -n "$running_pid" ]]; then
  printf 'Refusing to replace the running candidate (PID %s). Use a new output directory or quit it yourself.\n' "$running_pid" >&2
  exit 1
fi
python3 tools/check-release-bundle.py build/release-mac/Build/Products/Release/FishtankMac.app \
  build/FishtankPad.xcarchive/Products/Applications/FishtankPad.app
mkdir -p "$candidate_dir"
ditto build/release-mac/Build/Products/Release/FishtankMac.app "$candidate_dir/Fishtank.app"
# Prefer a stable local development identity. Ad-hoc cdhash requirements change
# on every build and leave macOS notifications associated with obsolete sources.
local_sign_identity="${FISHTANK_MAC_SIGN_IDENTITY:-}"
if [[ -z "$local_sign_identity" ]]; then
  local_sign_identity="$(python3 - <<'PY_SIGN'
import re, subprocess
result=subprocess.run(['security','find-identity','-v','-p','codesigning'],capture_output=True,text=True,check=True)
names=re.findall(r'"(Apple Development:[^"\n]+)"',result.stdout)
if len(names)==1: print(names[0])
elif len(names)>1: raise SystemExit('Multiple development identities; set FISHTANK_MAC_SIGN_IDENTITY explicitly.')
else: print('-')
PY_SIGN
)"
fi
codesign --force --options runtime --entitlements Configuration/FishtankMac.entitlements --sign "$local_sign_identity" "$candidate_dir/Fishtank.app"
codesign --verify --deep --strict --verbose=2 "$candidate_dir/Fishtank.app"
ditto -c -k --sequesterRsrc --keepParent "$candidate_dir/Fishtank.app" "$candidate_dir/Fishtank-1.2.3-mac-local.zip"
python3 - "$candidate_dir" <<'PY'
import hashlib, json, os, pathlib, subprocess, sys, zipfile
root=pathlib.Path(sys.argv[1]).resolve()
files=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z']).decode().split('\0')
files=sorted({f for f in files if f and pathlib.Path(f).is_file()
              and not pathlib.Path(f).resolve().is_relative_to(root)})
digest=hashlib.sha256()
with zipfile.ZipFile(root/'Fishtank-1.2.3-source.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
 for name in files:
  data=pathlib.Path(name).read_bytes()
  digest.update(name.encode()+b'\0'+data+b'\0')
  archive.write(name,arcname='fishtank-apple/'+name)
readiness=json.loads(pathlib.Path('Configuration/ReleaseReadiness.json').read_text())
assert readiness['version']=='1.2.3' and readiness['releaseReady'] is False
binary=root/'Fishtank.app/Contents/MacOS/FishtankMac'
pad_archive=pathlib.Path('build/FishtankPad.xcarchive').resolve()
manifest={'version':'1.2.3','status':'local-candidate-pending-platform-acceptance',
 'macArchitectures':['arm64','x86_64'],'macSigning':('ad-hoc-local-only' if 'Signature=adhoc' in subprocess.run(['codesign','-dv',str(root/'Fishtank.app')],capture_output=True,text=True,check=True).stderr else 'development-local-only'),
 'iPadArchive':os.path.relpath(pad_archive,root)+' (unsigned; not an installable IPA)',
 'distributionChannels':readiness['distributionChannels'],
 'releaseReadiness':readiness,
 'macBuildUUIDs':[line.split()[1:3] for line in subprocess.check_output(['dwarfdump','--uuid',str(binary)],text=True).splitlines()],
 'macExecutableSHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),
 'sourceDigest':digest.hexdigest(),
 'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.glob('*.zip'))}}
(root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
PY
