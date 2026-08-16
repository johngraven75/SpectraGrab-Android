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

if property_value("ApplicationDisplayVersion") != "0.3.0":
    raise SystemExit("ApplicationDisplayVersion must be 0.3.0 for this coordinated release")
if property_value("ApplicationVersion") != "3":
    raise SystemExit("ApplicationVersion must be the monotonically increasing value 3")

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
    "publish-test:",
    "SpectraGrab-Android-v$env:RELEASE_VERSION-TEST.apk",
    "Android Debug",
    "android-runtime-smoke.sh",
    "available=false",
    "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7",
    "actions/setup-dotnet@a98b56852c35b8e3190ac28c8c2271da59106c68 # v6",
    "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7",
    "actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131 # v7",
]
missing = [fragment for fragment in required_fragments if fragment not in workflow]
if missing:
    raise SystemExit(f"Release workflow is missing required production gates: {missing}")

if re.search(r"gh release (?:create|upload)[^\n]*\*\.apk", workflow):
    raise SystemExit("Release publication must never use an unrestricted APK glob")
if "branches: [main]" not in workflow:
    raise SystemExit("The Android release workflow must validate the main branch")

for required_path in (
    root / "scripts/android-runtime-smoke.sh",
    root / "scripts/runtime-smoke-server.py",
):
    if not required_path.is_file():
        raise SystemExit(f"Missing runtime release gate dependency: {required_path.relative_to(root)}")

main_page = (root / "MainPage.xaml").read_text(encoding="utf-8")
download_service = (root / "Services/MobileAutomatedDownloadService.cs").read_text(encoding="utf-8")
if "Stop Download" not in main_page or ".partial" not in download_service or "DeleteIfExists" not in download_service:
    raise SystemExit("Android stop control and atomic partial-file cleanup must remain enabled")

print("Verified Android version 0.3.0 (code 3), installable TEST publication, optional production signing, and emulator coverage.")
PY