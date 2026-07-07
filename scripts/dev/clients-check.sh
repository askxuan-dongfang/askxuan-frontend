#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

check_url() {
  local name="$1"
  local url="$2"
  local fallback_url="${url/127.0.0.1/localhost}"
  if curl -fsS "$url" >/dev/null 2>&1 || curl -fsS "$fallback_url" >/dev/null 2>&1; then
    echo "OK: $name $url"
  else
    echo "FAIL: $name $url" >&2
    FAILED=1
  fi
}

check_path() {
  local name="$1"
  local path="$2"
  if [ -e "$path" ]; then
    echo "OK: $name $path"
  else
    echo "FAIL: $name $path" >&2
    FAILED=1
  fi
}

check_url "寺院管理台" "http://127.0.0.1:5173/login"
check_url "商城管理台" "http://127.0.0.1:5174/login"
check_url "平台管理台" "http://127.0.0.1:5175/login"
check_path "C 端 iOS workspace" "$ROOT_DIR/apps/ios-customer/DongFangApp.xcworkspace"
check_path "大师端 iOS workspace" "$ROOT_DIR/apps/ios-master/MasterApp.xcworkspace"

if [ "$FAILED" -eq 0 ]; then
  echo "OK: 五个客户端入口检查通过"
else
  exit 1
fi
