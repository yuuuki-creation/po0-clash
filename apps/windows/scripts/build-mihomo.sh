#!/usr/bin/env bash
# Builds mihomo.exe from the pinned upstream submodule into the Tauri resources directory.
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
src="${MIHOMO_SRC:-$root/mihomo/upstream}"
out="$root/apps/windows/src-tauri/resources/mihomo.exe"
version="$(git -C "$src" describe --tags --always 2>/dev/null || echo unknown)"

mkdir -p "$(dirname "$out")"
cd "$src"
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -trimpath \
  -ldflags "-s -w -X github.com/metacubex/mihomo/constant.Version=$version" \
  -tags with_gvisor -o "$out" .
echo "built $out ($version)"
