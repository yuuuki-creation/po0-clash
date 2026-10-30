#!/usr/bin/env bash
# Cross-builds the NSIS installer on a Linux host with cargo-xwin, clang/lld and the distro's makensis.
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
shims="$root/target/windows-shims"
real_makensis="$(command -v makensis)"
mkdir -p "$shims/bin" "$shims/pkgconfig" "$shims/nsis/Win"

# cargo-xwin compiles C with clang-cl, which is plain clang started under that name.
ln -sf "$(command -v clang)" "$shims/bin/clang-cl"

# On a Linux host tauri-cli looks up the tray library for Linux packages even when the target is Windows.
cat >"$shims/pkgconfig/ayatana-appindicator3-0.1.pc" <<'EOF'
libdir=/usr/lib
Name: ayatana-appindicator3-0.1
Description: placeholder for tauri-cli
Version: 0.5.0
Libs: -L${libdir}
EOF

# Tauri's installer template includes Win\RestartManager.nsh, which NSIS only ships from 3.09 on.
header="$shims/nsis/Win/RestartManager.nsh"
[ -s "$header" ] || curl -fsSL https://raw.githubusercontent.com/kichik/nsis/v313/Include/Win/RestartManager.nsh -o "$header"
printf '#!/bin/sh\nexec "%s" "-X!addincludedir %s" "$@"\n' "$real_makensis" "$shims/nsis" >"$shims/bin/makensis"
chmod +x "$shims/bin/makensis"

export PATH="$shims/bin:$PATH"
export PKG_CONFIG_PATH="$shims/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

[ -f "$root/apps/windows/src-tauri/resources/mihomo.exe" ] || "$root/apps/windows/scripts/build-mihomo.sh"
cd "$root/apps/windows"
npm ci --no-fund --no-audit
npx tauri build --runner cargo-xwin --target x86_64-pc-windows-msvc --bundles nsis
ls -l "$root"/target/x86_64-pc-windows-msvc/release/bundle/nsis/*-setup.exe
