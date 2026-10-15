#!/usr/bin/env bash
set -euo pipefail
app_root="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?Usage: build.sh /absolute/output-directory}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
xcodebuild -project "$app_root/AskXuanAdmin.xcodeproj" -scheme AskXuanAdmin \
  -configuration Release -derivedDataPath "$output_dir/build" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
app_bundle="$output_dir/build/Build/Products/Release/AskXuanAdmin.app"
codesign --force --sign - --entitlements "$app_root/AskXuanAdmin/AskXuanAdmin.entitlements" "$app_bundle"
codesign --verify --deep --strict "$app_bundle"
ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$output_dir/AskXuanAdmin-macOS-universal.zip"
printf 'Built: %s\n' "$output_dir/AskXuanAdmin-macOS-universal.zip"
