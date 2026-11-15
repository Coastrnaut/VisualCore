#!/bin/sh
# scan-claims-release.sh — feature 094 (A12-P06) T-A12-608 (FR-A12-621; SC-A12-603; clarification 2). Modelled on
# specs/087-pp-p06-release/scan-claims-release.sh. Two checks:
# 1. The store text and the interface Swift of Tiny Worlds (controls, presenter, pack and preset names) contain none of
#    the refused words of A12-P05 (accurate, accuracy, precise, precision, scientific, realistic, real-world,
#    geographic, fps, frames per second, battery, a millisecond figure; whole words, case-insensitive).
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Tiny Worlds package, the VisualCore packages or the app's tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/tiny-worlds/store-listing.md"
tw="$root/Packages/ExperiencesCreative/TinyWorlds"
swift="$tw/Experience/WorldsControls.swift $tw/Experience/WorldsPresenter.swift $tw/Core/WorldPack.swift $tw/Core/WorldPreset.swift"
problems=0
if [ ! -f "$store" ]; then echo "PROBLEM: $store is missing"; echo "FAIL: claims scan"; exit 1; fi
words='accurate|accuracy|precise|precision|scientific|realistic|real-world|geographic|fps|frames per second|battery|[0-9]+([.,][0-9]+)? ?ms'
for file in "$store" $swift; do
    hits=$(grep -n '' "$file" | grep -iwE "$words")
    if [ -n "$hits" ]; then
        printf '%s\n' "$hits" | while IFS= read -r line; do echo "PROBLEM: refused claim in ${file#$root/}: $line"; done
        problems=$((problems + 1))
    fi
done
tests=$(grep -E '^\|' "$store" | grep -oE '[A-Za-z0-9]+\.swift[ `]+[A-Za-z_][A-Za-z0-9_]*' | sed -E 's/.*\.swift[ `]+//')
count=0
for name in $tests; do
    count=$((count + 1))
    if ! grep -rqE "func $name[ (]" "$tw" "$root/Packages/VisualCore/Tests" "$root/Packages/VisualCoreRendering/Tests" "$root/Apps/VisualCore/Tests" 2>/dev/null; then
        echo "PROBLEM: proving test '$name' named in store-listing.md does not exist"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
