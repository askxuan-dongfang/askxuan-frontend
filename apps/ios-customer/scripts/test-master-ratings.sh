#!/bin/bash
set -euo pipefail
script_dir=$(cd "$(dirname "$0")" && pwd)
app_root=$(cd "$script_dir/.." && pwd)
output_dir=${MASTER_RATINGS_TEST_OUTPUT_DIR:-"${TMPDIR:-/tmp}/askxuan-master-ratings-tests"}
mkdir -p "$output_dir/module-cache"
xcrun swiftc -swift-version 5 -module-cache-path "$output_dir/module-cache" \
  "$app_root/DongFangApp/Models/Master.swift" \
  "$app_root/DongFangApp/Features/Master/MasterListViewModel.swift" \
  "$app_root/Tests/MasterRatingsRegression.swift" \
  -o "$output_dir/master-ratings-regression"
"$output_dir/master-ratings-regression" > "$output_dir/results.json"
cat "$output_dir/results.json"
