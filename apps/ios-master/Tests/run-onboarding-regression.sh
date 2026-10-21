#!/bin/sh
set -eu
task_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
scratch_dir=$(mktemp -d "${TMPDIR:-/tmp}/askxuan-onboarding-tests.XXXXXX")
trap 'rm -rf "$scratch_dir"' EXIT HUP INT TERM
mkdir -p "$scratch_dir/Sources/OnboardingRules" "$scratch_dir/Tests/OnboardingRulesTests"
cp "$task_dir/../MasterApp/Features/Workspace/OnboardingAffiliation.swift" "$scratch_dir/Sources/OnboardingRules/"
cp "$task_dir/OnboardingAffiliationTests.swift" "$scratch_dir/Tests/OnboardingRulesTests/"
cat > "$scratch_dir/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "OnboardingRules",
    platforms: [.macOS(.v14)],
    products: [.library(name: "OnboardingRules", targets: ["OnboardingRules"])],
    targets: [.target(name: "OnboardingRules"), .testTarget(name: "OnboardingRulesTests", dependencies: ["OnboardingRules"])],
    swiftLanguageModes: [.v5]
)
SWIFT
swift test --package-path "$scratch_dir"
