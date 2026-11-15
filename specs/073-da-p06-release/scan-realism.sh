#!/bin/sh
# scan-realism.sh — feature 073 (A09-P06) T-A09-607 (FR-A09-621; SC-A09-603; clarification 2). Two checks:
# 1. The store text and the interface Swift of Digital Aquarium contain none of the realism and animal-care words
#    (whole words, case-insensitive).
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    aquarium's packages or the app's tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/digital-aquarium/store-listing.md"
swift="$root/Packages/ExperiencesCreative/DigitalAquarium/Experience/AquariumControls.swift $root/Packages/ExperiencesCreative/DigitalAquarium/Experience/AquariumPresenter.swift $root/Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumWording.swift"
problems=0
for word in realistic lifelike "real fish" pet "care for" healthy hungry starve nutrition therapy; do
    hits=$(grep -niwE "$word" "$store" $swift 2>/dev/null)
    if [ -n "$hits" ]; then
        echo "$hits" | while IFS= read -r line; do echo "PROBLEM: '$word': $line"; done
        problems=$((problems + 1))
    fi
done
tests=$(grep -E '^\|' "$store" | grep -oE '[A-Za-z0-9]+\.swift[ `]+[A-Za-z_][A-Za-z0-9_]*' | sed -E 's/.*\.swift[ `]+//')
count=0
for name in $tests; do
    count=$((count + 1))
    if ! grep -rqE "func $name[ (]" "$root/Packages/ExperiencesCreative/DigitalAquarium" "$root/Apps/VisualCore/Tests" 2>/dev/null; then
        echo "PROBLEM: proving test '$name' named in store-listing.md does not exist"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: realism scan, $problems problems"; exit 1; fi
echo "PASS: realism scan, $count proving tests found"
