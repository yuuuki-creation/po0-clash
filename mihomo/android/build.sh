#!/usr/bin/env bash
# Builds libmihomo.so for one Android ABI: build.sh <abi> <jniLibs dir> [min api]
set -euo pipefail

abi=$1
out=$2
api=${3:-26}
here=$(cd "$(dirname "$0")" && pwd)
ndk=${ANDROID_NDK_HOME:?ANDROID_NDK_HOME is not set}
bin="$ndk/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin"

goarm=
case $abi in
  arm64-v8a) goarch=arm64 cc=aarch64-linux-android$api-clang ;;
  armeabi-v7a) goarch=arm goarm=7 cc=armv7a-linux-androideabi$api-clang ;;
  x86_64) goarch=amd64 cc=x86_64-linux-android$api-clang ;;
  *) echo "unsupported ABI: $abi" >&2; exit 1 ;;
esac

version=$(git -C "$here/../upstream" describe --tags --always 2>/dev/null || echo unknown)
mkdir -p "$out/$abi"
CGO_ENABLED=1 GOOS=android GOARCH=$goarch GOARM=$goarm CC="$bin/$cc" \
  go build -C "$here" -trimpath -buildmode=c-shared -tags with_gvisor,cmfa \
  -ldflags "-s -w -X github.com/metacubex/mihomo/constant.Version=$version -extldflags=-Wl,-z,max-page-size=16384" \
  -o "$out/$abi/libmihomo.so" .
rm -f "$out/$abi/libmihomo.h"
