#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
python_command="python3"
if ! command -v "$python_command" >/dev/null 2>&1; then
  python_command="python"
fi

"$python_command" - "$repo_root" <<'PY'
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1])
project = ET.parse(root / "SpectraGrab.Android.csproj").getroot()

def property_value(name):
    node = project.find(f".//{name}")
    return "" if node is None or node.text is None else node.text.strip()

if property_value("ApplicationDisplayVersion") != "0.2.0":
    raise SystemExit("ApplicationDisplayVersion must be 0.2.0 for this production release")
if property_value("ApplicationVersion") != "2":
    raise SystemExit("ApplicationVersion must be the monotonically increasing value 2")

workflow = (root / ".github/workflows/android-ci-release.yml").read_text(encoding="utf-8")
required_fragments = [
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
    "AndroidKeyStore=true",
    "*-Signed.apk",
    "*-Signed.aab",
    "runtime-smoke:",
    "needs: runtime-smoke",
    "android-runtime-smoke.sh",
    "Retire unsigned Build 23 assets",
]
missing = [fragment for fragment in required_fragments if fragment not in workflow]
if missing:
    raise SystemExit(f"Release workflow is missing required production gates: {missing}")

if re.search(r"gh release (?:create|upload)[^\n]*\*\.apk", workflow):
    raise SystemExit("Release publication must never use an unrestricted APK glob")
if "branches: [main, agent/complete-capture-and-config]" not in workflow:
    raise SystemExit("The feature branch must run the signed emulator gate before merge")

for required_path in (
    root / "scripts/android-runtime-smoke.sh",
    root / "scripts/runtime-smoke-server.py",
):
    if not required_path.is_file():
        raise SystemExit(f"Missing runtime release gate dependency: {required_path.relative_to(root)}")

print("Verified Android version 0.2.0 (code 2), production signing gates, emulator coverage, and signed-only release publication.")
PY
