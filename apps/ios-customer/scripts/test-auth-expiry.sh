#!/bin/bash
set -euo pipefail
script_dir=$(cd "$(dirname "$0")" && pwd)
frontend_root=$(cd "$script_dir/../../.." && pwd)
output_dir=${AUTH_TEST_OUTPUT_DIR:-"${TMPDIR:-/tmp}/askxuan-auth-expiry-tests"}
mkdir -p "$output_dir/module-cache"
for role in customer master; do
  app=DongFangApp
  flags=(-D AUTH_REGRESSION)
  if [ "$role" = master ]; then app=MasterApp; flags+=(-D MASTER); fi
  network="$frontend_root/apps/ios-$role/$app/Core/Network"
  xcrun swiftc -swift-version 5 -module-cache-path "$output_dir/module-cache" "${flags[@]}" \
    "$network/APIResponse.swift" "$network/APIClient.swift" \
    "$frontend_root/apps/ios-customer/Tests/AuthExpiryRegression.swift" \
    -o "$output_dir/$role-auth-regression"
  "$output_dir/$role-auth-regression" > "$output_dir/$role-auth-results.json"
  cat "$output_dir/$role-auth-results.json"
done
