#!/bin/sh
# scan-identifiers.sh — feature 175 (A24-P03) T-A24-311 (FR-A24-307; SC-A24-304; clarification Q5). Modelled on
# specs/164-ss-p06-release/scan-sources-release.sh. Refuses, in the Graphics Benchmark Lab sources, every unique device
# or person identifier and every private or dynamically loaded framework: identifierForVendor, advertisingIdentifier,
# ASIdentifierManager, UIDevice.current.name, dlopen, dlsym, NSClassFromString, PrivateFrameworks, and any network use.
# Exits 1 with the matching lines when one is found, 0 otherwise. Run from the repository root.
set -u
dir="Packages/ExperiencesCreative/GraphicsBenchmarkLab"
pattern='identifierForVendor|advertisingIdentifier|ASIdentifierManager|UIDevice\.current\.name|\.current\.name\b|dlopen|dlsym|NSClassFromString|PrivateFrameworks|URLSession|import Network'
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "FAIL: identifier or private use found in $dir"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no identifier or private use in $files Swift files of $dir"
