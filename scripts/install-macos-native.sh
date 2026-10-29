#!/usr/bin/env bash
# Installs the native po0-clash (SwiftUI, macOS 13+) into /Applications, replacing an older copy of either the
# native or the Flutter build. Settings and data stay where they are; the first launch of the native app imports
# the Flutter build's subscriptions and whitelist tokens.
#
#   install-macos-native.sh [<release tag> | <path to po0-clash-macos.zip>]   (default: the latest release)
#   curl -fsSL https://raw.githubusercontent.com/yuuuki-creation/po0-clash/main/scripts/install-macos-native.sh | bash
#
#   PO0CLASH_REPO    owner/repo (default: yuuuki-creation/po0-clash)
#   PO0CLASH_SHA256  expected SHA-256 of the zip; a release asset's own digest is checked automatically
#   GH_TOKEN         token for API rate limits or a private repository
set -euo pipefail
# macOS ships bash 3.2, where "${a[@]}" on an empty array trips set -u; arrays expand as ${a[@]+"${a[@]}"}.

repo="${PO0CLASH_REPO:-yuuuki-creation/po0-clash}"
source_arg="${1:-latest}"
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

download() {
  local endpoint auth=() release asset
  if [ "$source_arg" = latest ]; then
    endpoint="https://api.github.com/repos/$repo/releases/latest"
  else
    endpoint="https://api.github.com/repos/$repo/releases/tags/$source_arg"
  fi
  [ -z "${GH_TOKEN:-}" ] || auth=(-H "Authorization: Bearer $GH_TOKEN")
  release="$(curl -fsSL ${auth[@]+"${auth[@]}"} -H "Accept: application/vnd.github+json" "$endpoint")" ||
    die "cannot read release $source_arg of $repo"
  # JavaScript for Automation ships with every macOS; jq and python do not.
  asset="$(osascript -l JavaScript -e '
    function run(argv) {
      const assets = JSON.parse(argv[0]).assets || [];
      const asset = assets.find((a) => /^po0-clash(-[^/]+)?-macos\.zip$/.test(a.name));
      return asset ? asset.url + " " + (asset.digest || "").replace(/^sha256:/, "") : "";
    }' "$release")"
  [ -n "$asset" ] || die "release $source_arg has no native macOS build (po0-clash-macos.zip)"
  set -- $asset
  [ -n "$expected" ] || expected="${2:-}"
  echo "Downloading po0-clash $source_arg..."
  curl -fL --progress-bar ${auth[@]+"${auth[@]}"} -H "Accept: application/octet-stream" -o "$zip" "$1"
}

case "$source_arg" in
  *.zip | */*)
    [ -f "$source_arg" ] || die "no such file: $source_arg"
    cp "$source_arg" "$zip"
    ;;
  *) download ;;
esac

actual="$(shasum -a 256 "$zip" | cut -d' ' -f1)"
if [ -n "$expected" ]; then
  [ "$actual" = "$expected" ] || die "checksum mismatch: got $actual, expected $expected"
  echo "Checksum verified."
fi

ditto -x -k "$zip" "$work/unpacked" 2>/dev/null || die "the download is not a valid zip"
app="$work/unpacked/po0-clash.app"
[ -d "$app" ] || die "po0-clash.app is not in the zip"
plist="$app/Contents/Info.plist"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null)" = "$bundle_id" ] ||
  die "the zip does not contain po0-clash"
[ -x "$app/Contents/MacOS/mihomo" ] || die "the zip does not contain the native po0-clash"
lipo -archs "$app/Contents/MacOS/po0-clash" | tr ' ' '\n' | grep -qx "$(uname -m)" ||
  die "this build does not run on $(uname -m)"
codesign --verify --strict "$app" 2>/dev/null || die "the app's signature does not match its contents"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"

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
