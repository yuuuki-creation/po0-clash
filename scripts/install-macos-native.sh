#!/usr/bin/env bash
# Installs the native po0-clash (SwiftUI, macOS 13+) into /Applications, replacing an older copy of either the
# native or the Flutter build. Settings and data stay where they are; the first launch of the native app imports
# the Flutter build's subscriptions and whitelist tokens.
#
#   install-macos-native.sh [<version> | <path to po0-clash-macos.zip>]
#
# Native builds are released under native-v* tags (7.0.0-beta.1, v7.0.0-beta.1 and native-v7.0.0-beta.1 name the
# same release); without a version the newest stable native release is installed.
#
#   PO0CLASH_REPO    owner/repo (default: yuuuki-creation/po0-clash)
#   PO0CLASH_SHA256  expected SHA-256 of the zip; a release asset's own digest is checked automatically
#   GH_TOKEN         token for API rate limits or a private repository
#   PO0CLASH_API     GitHub API base URL (CI points it at a local stand-in)
set -euo pipefail
# macOS ships bash 3.2, where "${a[@]}" on an empty array trips set -u; arrays expand as ${a[@]+"${a[@]}"}.

repo="${PO0CLASH_REPO:-yuuuki-creation/po0-clash}"
api="${PO0CLASH_API:-https://api.github.com}"
source_arg="${1:-}"
bundle_id=io.github.yuuukicreation.po0clash
target=/Applications/po0-clash.app
expected="${PO0CLASH_SHA256:-}"

die() {
  echo "error: $*" >&2
  exit 1
}

[ "$(uname -s)" = Darwin ] || die "this installer only runs on macOS"
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || die "po0-clash needs macOS 13 or later"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
zip="$work/po0-clash-macos.zip"

download_tagged() {
  local tag="native-v$1" base manifest="$work/SHA256SUMS.txt"
  base="https://github.com/$repo/releases/download/$tag"
  if [ -z "$expected" ]; then
    /usr/bin/curl -q -fsSL --retry 3 -o "$manifest" "$base/SHA256SUMS.txt" ||
      die "cannot download the checksums for $tag"
    expected="$(awk '$2 == "po0-clash-macos.zip" || $2 == "*po0-clash-macos.zip" { print $1; exit }' "$manifest")"
  fi
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || die "release $tag does not publish a valid checksum"
  echo "Downloading po0-clash $tag..."
  /usr/bin/curl -q -fL --retry 3 --progress-bar -o "$zip" "$base/po0-clash-macos.zip"
}

download_api() {
  local endpoint auth=() metadata="$work/release.json" found tag url digest
  case "$source_arg" in
    "") endpoint="$api/repos/$repo/releases?per_page=50" ;;
    native-v*) endpoint="$api/repos/$repo/releases/tags/$source_arg" ;;
    v*) endpoint="$api/repos/$repo/releases/tags/native-$source_arg" ;;
    *) endpoint="$api/repos/$repo/releases/tags/native-v$source_arg" ;;
  esac
  [ -z "${GH_TOKEN:-}" ] || auth=(-H "Authorization: Bearer $GH_TOKEN")
  /usr/bin/curl -q -fsSL --retry 3 ${auth[@]+"${auth[@]}"} -H "Accept: application/vnd.github+json" -o "$metadata" "$endpoint" ||
    die "cannot find the native release ${source_arg:-list} in $repo"
  found="$(/usr/bin/osascript -l JavaScript -e '
    ObjC.import("Foundation");
    function run(argv) {
      const source = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null);
      const data = JSON.parse(ObjC.unwrap(source));
      const release = Array.isArray(data)
        ? data.find((r) => !r.draft && !r.prerelease && r.tag_name.startsWith("native-v"))
        : data;
      if (!release) return "";
      const asset = (release.assets || []).find((a) => /^po0-clash(-[^/]+)?-macos\.zip$/.test(a.name));
      if (!asset) return release.tag_name;
      return [release.tag_name, asset.url, (asset.digest || "").replace(/^sha256:/, "")].join("\t");
    }' "$metadata")" || die "cannot read the release metadata"
  [ -n "$found" ] || die "$repo has no stable native release yet"
  IFS=$'\t' read -r tag url digest <<< "$found"
  [ -n "$url" ] || die "release $tag has no po0-clash-macos.zip"
  [ -n "$expected" ] || expected="$digest"
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || die "release $tag does not publish a valid checksum"
  echo "Downloading po0-clash $tag..."
  /usr/bin/curl -q -fL --retry 3 --progress-bar ${auth[@]+"${auth[@]}"} -H "Accept: application/octet-stream" -o "$zip" "$url"
}

case "$source_arg" in
  *.zip | */*)
    [ -f "$source_arg" ] || die "no such file: $source_arg"
    cp "$source_arg" "$zip"
    ;;
  *)
    version_arg="${source_arg#native-}"
    version_arg="${version_arg#v}"
    if [ "$repo" = "yuuuki-creation/po0-clash" ] && [ -z "${PO0CLASH_API:-}${GH_TOKEN:-}" ] &&
       [[ "$version_arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
      download_tagged "$version_arg"
    else
      download_api
    fi
    ;;
esac

actual="$(shasum -a 256 "$zip" | cut -d' ' -f1)"
if [ -n "$expected" ]; then
  [ "$actual" = "$(printf %s "$expected" | tr A-F a-f)" ] || die "checksum mismatch: got $actual, expected $expected"
  echo "Checksum verified."
fi

ditto -x -k "$zip" "$work/unpacked" 2>/dev/null || die "the download is not a valid zip"
app="$work/unpacked/po0-clash.app"
[ -d "$app" ] || die "po0-clash.app is not in the zip"
plist="$app/Contents/Info.plist"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null)" = "$bundle_id" ] ||
  die "the zip does not contain po0-clash"
[ -x "$app/Contents/MacOS/mihomo" ] || die "the zip does not contain the native po0-clash"
/usr/bin/file -b "$app/Contents/MacOS/po0-clash" | grep -w "$(uname -m)" >/dev/null ||
  die "this build does not run on $(uname -m)"
codesign --verify --strict "$app" 2>/dev/null || die "the app's signature does not match its contents"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
[ -z "${PO0CLASH_DOWNLOAD_ONLY:-}" ] || exit 0

running() {
  pgrep -x -U "$UID" po0-clash >/dev/null 2>&1
}

wait_gone() {
  local i
  for i in $(seq "$1"); do
    running || return 0
    sleep 0.5
  done
  ! running
}

if running; then
  echo "Quitting the running po0-clash..."
  if [ -x "$target/Contents/MacOS/mihomo" ]; then
    # The native app shuts its core down and clears the system proxy on SIGTERM.
    pkill -TERM -x -U "$UID" po0-clash || true
    wait_gone 30 || pkill -KILL -x -U "$UID" po0-clash || true
  else
    # The Flutter build cleans up only on a normal quit; the first Apple event may wait for the user's consent.
    osascript -e "if application id \"$bundle_id\" is running then tell application id \"$bundle_id\" to quit" \
      >/dev/null 2>&1 &
    quitter=$!
    if ! wait_gone 40; then
      pkill -TERM -x -U "$UID" po0-clash || true
      wait_gone 10 || pkill -KILL -x -U "$UID" po0-clash || true
      echo "warning: the old po0-clash was stopped without quitting; if it had the system proxy on, connect and" \
        "disconnect once in the new po0-clash (or turn the proxy off in System Settings > Network) to clear it." >&2
    fi
    kill "$quitter" 2>/dev/null || true
  fi
fi
# The Flutter build's engine runs from inside the bundle being replaced.
pkill -x -U "$UID" Po0ClashCore 2>/dev/null || true

echo "Installing po0-clash $version to $target..."
sudo_cmd=()
[ -w /Applications ] || sudo_cmd=(sudo)
if [ -e "$target" ]; then
  ${sudo_cmd[@]+"${sudo_cmd[@]}"} rm -rf "$target" 2>/dev/null || sudo rm -rf "$target"
fi
${sudo_cmd[@]+"${sudo_cmd[@]}"} ditto "$app" "$target"
# Ad-hoc signed and not notarized (ADR 0018): without this Gatekeeper refuses the first launch.
${sudo_cmd[@]+"${sudo_cmd[@]}"} xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

echo "Opening po0-clash..."
open "$target"
