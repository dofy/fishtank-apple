#!/bin/bash
# Make an isolated copy of the release candidate for local GUI acceptance.
# Only bundle identity/signature change; the executable and game resources stay identical.
set -euo pipefail
cd "$(dirname "$0")/.."
validation_source="build/distribution/1.3.1-candidate/Fishtank.app"
validation_target="build/validation/Fishtank-QA.app"
verify_existing=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source|--output)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        printf 'Missing path for %s\n' "$1" >&2; exit 1
      fi
      if [[ "$1" == --source ]]; then validation_source="$2"; else validation_target="$2"; fi
      shift 2 ;;
    --verify-existing) verify_existing=true; shift ;;
    *) printf 'Usage: %s [--source app] [--output new-app] [--verify-existing]\n' "$0" >&2; exit 1 ;;
  esac
done
if [[ ! -d "$validation_source/Contents" ]]; then
  printf 'Candidate app does not exist: %s\n' "$validation_source" >&2
  exit 1
fi
if [[ "$verify_existing" == true && ! -d "$validation_target" ]]; then
  printf 'QA copy does not exist: %s\n' "$validation_target" >&2
  exit 1
fi
if [[ ( -e "$validation_target" || -L "$validation_target" ) && "$verify_existing" != true ]]; then
  printf 'QA copy already exists: %s\n' "$validation_target"
  printf 'Use a fresh validation directory or archive the existing QA copy before replacing it.\n' >&2
  exit 1
fi
mkdir -p "$(dirname "$validation_target")"
if [[ ! -e "$validation_target" ]]; then
ditto "$validation_source" "$validation_target"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier net.yahaha.fishtank.mac.validation' "$validation_target/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Fishtank QA' "$validation_target/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Fishtank QA' "$validation_target/Contents/Info.plist"
codesign --force --options runtime --entitlements Configuration/FishtankMac.entitlements --sign - "$validation_target"
fi
codesign --verify --deep --strict --verbose=2 "$validation_target"
python3 - "$validation_source" "$validation_target" <<'PY'
import hashlib,pathlib,plistlib,re,subprocess,sys
source=pathlib.Path(sys.argv[1])/'Contents'
qa=pathlib.Path(sys.argv[2])/'Contents'
info=plistlib.loads((qa/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='net.yahaha.fishtank.mac.validation'
checked=0
for p in source.rglob('*'):
 if not p.is_file():continue
 relative=p.relative_to(source)
 if relative==pathlib.Path('Info.plist') or relative.parts[0] in ['_CodeSignature','MacOS']:continue
 assert hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256((qa/relative).read_bytes()).digest(),relative
 checked+=1
binary=info['CFBundleExecutable']
def code(path):
 text=subprocess.check_output(['otool','-arch','all','-s','__TEXT','__text',str(path)],text=True)
 lines=[line for line in text.splitlines() if re.match(r'^[0-9a-fA-F]+\s',line)]
 assert lines,'Missing machine-code section'
 return lines
assert code(source/'MacOS'/binary)==code(qa/'MacOS'/binary)
def uuid(path):
 return [line.split()[:3] for line in subprocess.check_output(['dwarfdump','--uuid',str(path)],text=True).splitlines()]
assert uuid(source/'MacOS'/binary)==uuid(qa/'MacOS'/binary)
print(f'PASS isolated QA identity; machine-code sections, build UUIDs and {checked} resources match the candidate.')
print('QA saves and preferences use their own macOS sandbox container.')
print('This script prepares the copy; it does not launch it or change the production save.')
PY
