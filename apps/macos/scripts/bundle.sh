#!/usr/bin/env bash
# Builds dist/po0-clash.app and dist/po0-clash-macos.zip. ARCHS="arm64 x86_64" makes a universal app;
# WITH_E2E=1 also builds the real-flow checker dist/po0-e2e (scripts/e2e.sh).
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(cd "$app_dir/../.." && pwd)"
archs="${ARCHS:-$(uname -m)}"
version="${VERSION:-}"
if [[ -z "$version" && -f "$root/Cargo.toml" ]]; then
  version="$(sed -n 's/^version *= *"\(.*\)"/\1/p' "$root/Cargo.toml" | head -n1)"
fi
version="${version:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
bundle_id=io.github.yuuukicreation.po0clash
work="$app_dir/.build/bundle"
dist="$app_dir/dist"
app="$dist/po0-clash.app"
export MACOSX_DEPLOYMENT_TARGET=13.0

rust_target() {
  case "$1" in
    arm64) echo aarch64-apple-darwin ;;
    x86_64) echo x86_64-apple-darwin ;;
    *) echo "unsupported arch: $1" >&2; exit 1 ;;
  esac
}

go_arch() {
  case "$1" in
    arm64) echo arm64 ;;
    x86_64) echo amd64 ;;
  esac
}

build_core() {
  local swift_dir="$app_dir/Sources/Po0FFI" header_dir="$app_dir/Sources/Po0FFIFFI" out="$work/bindings"
  rm -rf "$swift_dir" "$header_dir" "$app_dir/.ffi" "$out"
  local libs=() arch target
  for arch in $archs; do
    target="$(rust_target "$arch")"
    rustup target add "$target" >/dev/null
    cargo build --manifest-path "$root/Cargo.toml" -p po0-ffi --release --target "$target"
    libs+=("$root/target/$target/release/libpo0_ffi.a")
  done
  mkdir -p "$app_dir/.ffi/lib" "$swift_dir" "$header_dir" "$out"
  lipo -create "${libs[@]}" -output "$app_dir/.ffi/lib/libpo0_ffi.a"

  # Release builds strip the UniFFI metadata, so the bindings come from an unstripped host debug build.
  cargo build --manifest-path "$root/Cargo.toml" -p po0-ffi
  cargo run --manifest-path "$root/Cargo.toml" -p po0-ffi --features cli --bin uniffi-bindgen -- \
    generate --library "$root/target/debug/libpo0_ffi.dylib" --language swift --out-dir "$out"
  local swift_files=("$out"/*.swift) maps=("$out"/*.modulemap)
  if [[ ${#swift_files[@]} -ne 1 || ${#maps[@]} -ne 1 ]]; then
    echo "expected one Swift file and one module map from uniffi-bindgen, got: $(ls "$out")" >&2
    exit 1
  fi
  cp "${swift_files[0]}" "$swift_dir/Po0FFI.swift"
  cp "$out"/*.h "$header_dir/"
  cp "${maps[0]}" "$header_dir/module.modulemap"
  if ! grep -q 'module Po0FFIFFI' "$header_dir/module.modulemap"; then
    echo "the FFI module must be Po0FFIFFI (crates/ffi/uniffi.toml)" >&2
    exit 1
  fi
}

build_mihomo() {
  local src="$root/mihomo/upstream" outs=() arch out
  [[ -f "$src/go.mod" ]] || git -C "$root" submodule update --init --depth 1 mihomo/upstream
  local tag
  tag="$(git -C "$src" describe --tags --always 2>/dev/null || echo unknown)"
  for arch in $archs; do
    out="$work/mihomo-$arch"
    (cd "$src" && CGO_ENABLED=0 GOOS=darwin GOARCH="$(go_arch "$arch")" go build -trimpath \
      -ldflags "-s -w -X github.com/metacubex/mihomo/constant.Version=$tag" -tags with_gvisor -o "$out" .)
    outs+=("$out")
  done
  lipo -create "${outs[@]}" -output "$work/mihomo"
}

make_icon() {
  local set="$work/AppIcon.iconset" src="$app_dir/Resources/AppIcon.png" size
  rm -rf "$set"
  mkdir -p "$set"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$src" --out "$set/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$src" --out "$set/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$set" -o "$1"
}

build_app() {
  local bins=() e2e=() arch bin_dir
  for arch in $archs; do
    swift build --package-path "$app_dir" -c release --arch "$arch" --product po0-clash
    bin_dir="$(swift build --package-path "$app_dir" -c release --arch "$arch" --show-bin-path)"
    bins+=("$bin_dir/po0-clash")
    if [[ "${WITH_E2E:-}" == 1 ]]; then
      swift build --package-path "$app_dir" -c release --arch "$arch" --product po0-e2e
      e2e+=("$bin_dir/po0-e2e")
    fi
  done
  if [[ "${WITH_E2E:-}" == 1 ]]; then
    lipo -create "${e2e[@]}" -output "$dist/po0-e2e"
    codesign --force --sign - "$dist/po0-e2e"
  fi

  plutil -lint "$app_dir"/Resources/*.lproj/Localizable.strings >/dev/null
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  lipo -create "${bins[@]}" -output "$app/Contents/MacOS/po0-clash"
  cp "$work/mihomo" "$app/Contents/MacOS/mihomo"
  cp "$app_dir/Resources/Info.plist" "$app/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$build_number" "$app/Contents/Info.plist"
  cp -R "$app_dir/Resources/en.lproj" "$app_dir/Resources/zh-Hans.lproj" "$app/Contents/Resources/"
  cp "$app_dir"/Resources/MenuBarIcon*.png "$app/Contents/Resources/"
  make_icon "$app/Contents/Resources/AppIcon.icns"

  codesign --force --sign - "$app/Contents/MacOS/mihomo"
  codesign --force --sign - --identifier "$bundle_id" "$app"
  codesign --verify --strict "$app"
  rm -f "$dist/po0-clash-macos.zip"
  ditto -c -k --keepParent "$app" "$dist/po0-clash-macos.zip"
}

mkdir -p "$work" "$dist"
build_core
build_mihomo
build_app
echo "built $app ($version, $archs)"
