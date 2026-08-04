#!/usr/bin/env bash
set -euo pipefail

release_apk="${1:?release APK is required}"
upgrade_apk="${2:?upgrade test APK is required}"
package_id="com.johngraven75.spectragrab"
diagnostics="artifacts/runtime-diagnostics"
ui_dump="$diagnostics/window.xml"
server_log="$diagnostics/runtime-server.log"
logcat_file="$diagnostics/logcat.txt"
mkdir -p "$diagnostics"

python3 scripts/runtime-smoke-server.py --port 8765 >"$server_log" 2>&1 &
server_pid=$!
cleanup() {
  adb logcat -d >"$logcat_file" 2>&1 || true
  kill "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

dump_ui() {
  adb shell uiautomator dump /sdcard/window.xml >/dev/null
  adb exec-out cat /sdcard/window.xml >"$ui_dump"
}

ui_contains() {
  local needle="$1"
  dump_ui
  python3 - "$ui_dump" "$needle" <<'PY'
import sys
import xml.etree.ElementTree as ET

path, needle = sys.argv[1], sys.argv[2].lower()
root = ET.parse(path).getroot()
for node in root.iter("node"):
    haystack = " ".join((node.attrib.get("text", ""), node.attrib.get("content-desc", ""))).lower()
    if needle in haystack:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

wait_for_text() {
  local needle="$1"
  local attempts="${2:-60}"
  for _ in $(seq 1 "$attempts"); do
    if ui_contains "$needle"; then return 0; fi
    sleep 2
  done
  printf 'Timed out waiting for UI text: %s\n' "$needle" >&2
  cat "$ui_dump" >&2
  return 1
}

bounds_for_text() {
  local needle="$1"
  dump_ui
  python3 - "$ui_dump" "$needle" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

path, needle = sys.argv[1], sys.argv[2].lower()
root = ET.parse(path).getroot()
for node in root.iter("node"):
    haystack = " ".join((node.attrib.get("text", ""), node.attrib.get("content-desc", ""))).lower()
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.attrib.get("bounds", ""))
    if needle in haystack and match:
        left, top, right, bottom = map(int, match.groups())
        print(f"{(left + right) // 2} {(top + bottom) // 2}")
        raise SystemExit(0)
raise SystemExit(1)
PY
}

bounds_for_edit() {
  local index="$1"
  dump_ui
  python3 - "$ui_dump" "$index" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

path, index = sys.argv[1], int(sys.argv[2])
nodes = [node for node in ET.parse(path).getroot().iter("node") if node.attrib.get("class", "").endswith("EditText")]
if index >= len(nodes):
    raise SystemExit(1)
match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", nodes[index].attrib.get("bounds", ""))
if not match:
    raise SystemExit(1)
left, top, right, bottom = map(int, match.groups())
print(f"{(left + right) // 2} {(top + bottom) // 2}")
PY
}

tap_text() {
  local point
  point="$(bounds_for_text "$1")"
  read -r x y <<<"$point"
  adb shell input tap "$x" "$y"
}

enter_url() {
  local edit_index="$1"
  local value="$2"
  local point
  point="$(bounds_for_edit "$edit_index")"
  read -r x y <<<"$point"
  adb shell input tap "$x" "$y"
  adb shell input text "$value"
  adb shell input keyevent KEYCODE_BACK
}

launch_app() {
  adb shell am force-stop "$package_id"
  adb shell monkey -p "$package_id" -c android.intent.category.LAUNCHER 1 >/dev/null
  wait_for_text "Ready." 45
  wait_for_text "Verified 5 providers and 5 add-ins" 45
}

assert_private_file() {
  adb shell run-as "$package_id" test -f "$1"
}

replace_plugin_with_marker() {
  local plugin="$1"
  local app_path="files/config/plugins/${plugin}.json"
  local local_source="$diagnostics/${plugin}.json"
  local local_updated="$diagnostics/${plugin}-updated.json"
  local remote_path="/data/local/tmp/spectragrab-${plugin}.json"
  adb exec-out run-as "$package_id" cat "$app_path" >"$local_source"
  jq '.settings.runtimeVerificationMarker = "preserved-through-upgrade"' "$local_source" >"$local_updated"
  adb push "$local_updated" "$remote_path" >/dev/null
  adb shell chmod 644 "$remote_path"
  adb shell run-as "$package_id" cp "$remote_path" "$app_path"
  adb shell rm -f "$remote_path"
}

assert_plugin_marker() {
  local plugin="$1"
  adb exec-out run-as "$package_id" cat "files/config/plugins/${plugin}.json" | jq -e '.settings.runtimeVerificationMarker == "preserved-through-upgrade"' >/dev/null
}

adb wait-for-device
adb uninstall "$package_id" >/dev/null 2>&1 || true
adb install "$release_apk"
launch_app

for plugin in emby jellyfin plex localai quickconnect; do
  assert_private_file "files/config/plugins/${plugin}.json"
done

enter_url 0 'http://10.0.2.2:8765/direct.mp4'
tap_text 'AI Download & Organize'
wait_for_text 'Complete:' 60
assert_private_file 'files/Downloads/direct.mp4'
assert_private_file 'files/Downloads/direct.nfo'

launch_app
enter_url 0 'http://10.0.2.2:8765/vod/master.m3u8'
tap_text 'AI Download & Organize'
wait_for_text 'Complete:' 60
assert_private_file 'files/Downloads/master.ts'
assert_private_file 'files/Downloads/master.nfo'

launch_app
adb shell input swipe 540 1650 540 350 500
sleep 1
enter_url 1 'http://10.0.2.2:8765/vod/master.m3u8'
tap_text 'Start Capture'
wait_for_text 'Capture complete:' 60

launch_app
adb shell input swipe 540 1650 540 350 500
sleep 1
enter_url 1 'http://10.0.2.2:8765/live/live.m3u8'
tap_text 'Start Capture'
wait_for_text 'Capturing' 60
tap_text 'Stop & Finalize'
wait_for_text 'Stopped and finalized' 60

for plugin in emby jellyfin plex localai quickconnect; do
  replace_plugin_with_marker "$plugin"
  assert_plugin_marker "$plugin"
done

adb install -r "$upgrade_apk"
if ! adb shell dumpsys package "$package_id" | grep -q 'versionCode=3'; then
  printf '%s\n' 'The same-key upgrade APK was not installed as version code 3.' >&2
  exit 1
fi
launch_app
for plugin in emby jellyfin plex localai quickconnect; do
  assert_plugin_marker "$plugin"
done

printf '%s\n' 'Android runtime release gate passed: launch, direct/HLS download, Live Capture completion/stop, five add-ins, persistence, and same-key upgrade.'
