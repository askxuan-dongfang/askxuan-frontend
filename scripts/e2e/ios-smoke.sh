#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/e2e/artifacts/ios"
DEVICE="${IOS_DEVICE:-iPhone 17 Pro}"
DESTINATION="platform=iOS Simulator,name=$DEVICE"
SCREENSHOT_WAIT_SECONDS="${IOS_SMOKE_WAIT_SECONDS:-8}"
BASE="${BASE:-http://127.0.0.1:8080}"

mkdir -p "$ARTIFACT_DIR/customer" "$ARTIFACT_DIR/master"

boot_device() {
  xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
  xcrun simctl bootstatus booted -b
}

build_app() {
  local app_dir="$1"
  local project="$2"
  local scheme="$3"
  xcodebuild -project "$app_dir/$project" \
    -scheme "$scheme" \
    -destination "$DESTINATION" \
    -derivedDataPath "$app_dir/build" \
    build
}

install_launch_capture() {
  local app_path="$1"
  local bundle_id="$2"
  local app_key="$3"
  local tabs="$4"
  shift 4
  local launch_args=("$@")
  xcrun simctl terminate booted "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl uninstall booted "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install booted "$app_path"
  for tab in $tabs; do
    xcrun simctl terminate booted "$bundle_id" >/dev/null 2>&1 || true
    xcrun simctl launch booted "$bundle_id" "${launch_args[@]}" -tab "$tab" >/dev/null
    sleep "$SCREENSHOT_WAIT_SECONDS"
    xcrun simctl io booted screenshot "$ARTIFACT_DIR/$app_key/tab-$tab.png"
  done
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "错误：iOS smoke 登录态注入需要 jq" >&2
    exit 1
  fi
}

fetch_customer_credentials() {
  local resp
  resp="$(curl -sS -X POST "$BASE/api/v1/auth/login" \
    -H 'Content-Type: application/json' \
    -d '{"phone":"13800138000","code":"1234"}')"
  CUSTOMER_TOKEN="$(echo "$resp" | jq -r '.data.accessToken // empty')"
  CUSTOMER_REFRESH="$(echo "$resp" | jq -r '.data.refreshToken // empty')"
  CUSTOMER_USER_ID="$(echo "$resp" | jq -r '.data.userInfo.userId // empty')"
  if [ -z "$CUSTOMER_TOKEN" ] || [ -z "$CUSTOMER_USER_ID" ]; then
    echo "错误：无法获取 C 端 smoke 登录 token：$resp" >&2
    exit 1
  fi
}

fetch_master_credentials() {
  local resp
  resp="$(curl -sS -X POST "$BASE/api/v1/auth/admin/login" \
    -H 'Content-Type: application/json' \
    -d '{"account":"zhihai","password":"123456"}')"
  MASTER_TOKEN="$(echo "$resp" | jq -r '.data.accessToken // empty')"
  MASTER_REFRESH="$(echo "$resp" | jq -r '.data.refreshToken // empty')"
  if [ -z "$MASTER_TOKEN" ]; then
    echo "错误：无法获取法师端 smoke 登录 token：$resp" >&2
    exit 1
  fi
}

boot_device
require_jq
fetch_customer_credentials
fetch_master_credentials

CUSTOMER_DIR="$ROOT_DIR/apps/ios-customer"
MASTER_DIR="$ROOT_DIR/apps/ios-master"

build_app "$CUSTOMER_DIR" "DongFangApp.xcodeproj" "DongFangApp"
install_launch_capture \
  "$CUSTOMER_DIR/build/Build/Products/Debug-iphonesimulator/DongFangApp.app" \
  "com.dongfang.customer" \
  "customer" \
  "0 1 2 3 4" \
  --smoke-token "$CUSTOMER_TOKEN" \
  --smoke-refresh-token "$CUSTOMER_REFRESH" \
  --smoke-user-id "$CUSTOMER_USER_ID" \
  --smoke-nickname "问玄测试用户" \
  --smoke-mobile "13800138000"

build_app "$MASTER_DIR" "MasterApp.xcodeproj" "MasterApp"
install_launch_capture \
  "$MASTER_DIR/build/Build/Products/Debug-iphonesimulator/MasterApp.app" \
  "com.askxuan.master" \
  "master" \
  "0 1 2 3" \
  --smoke-token "$MASTER_TOKEN" \
  --smoke-refresh-token "$MASTER_REFRESH"

echo "iOS 冒烟截图已输出到：$ARTIFACT_DIR"
