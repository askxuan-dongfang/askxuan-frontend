#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
binary=$(mktemp /private/tmp/askxuan-ai-contract.XXXXXX)
trap 'rm -f "$binary"' EXIT
swiftc DongFangApp/Features/AiDivination/AiExperienceModels.swift Tests/AiExperienceContractRegression.swift -o "$binary"
"$binary"
