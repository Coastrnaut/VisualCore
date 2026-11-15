#!/bin/sh
# scan-claims-release.sh — feature 087 (A11-P06) T-A11-607 (FR-A11-621; SC-A11-603; clarification 2). Modelled on
# specs/080-na-p06-release/scan-claims-release.sh. Two checks:
# 1. The store text and the interface Swift of Physics Playground (controls, presenter, preset and tutorial text)
#    contain none of the refused accuracy, safety, prediction and learning-outcome words (whole words,
#    case-insensitive), after the two allowed denial phrases of clarification 2 are removed.
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Physics Playground package, the VisualCore packages or the app's tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/physics-playground/store-listing.md"
pp="$root/Packages/ExperiencesCreative/PhysicsPlayground"
swift="$pp/Experience/PlaygroundControls.swift $pp/Experience/PlaygroundPresenter.swift $pp/Core/Presets.swift $pp/Core/Tutorials.swift"
problems=0
if [ ! -f "$store" ]; then echo "PROBLEM: $store is missing"; echo "FAIL: claims scan"; exit 1; fi
words='accurate|accuracy|precise|precision|engineering-grade|safety|predict|prediction|teaches|learning outcomes?|improves? understanding'
for file in "$store" $swift; do
    hits=$(grep -n '' "$file" \
        | sed -e 's/The simulation is an educational approximation, not a precise physical measurement\.//g' \
              -e 's/Educational approximation//g' \
        | grep -iwE "$words")
    if [ -n "$hits" ]; then
        printf '%s\n' "$hits" | while IFS= read -r line; do echo "PROBLEM: refused claim in ${file#$root/}: $line"; done
        problems=$((problems + 1))
    fi
done
tests=$(grep -E '^\|' "$store" | grep -oE '[A-Za-z0-9]+\.swift[ `]+[A-Za-z_][A-Za-z0-9_]*' | sed -E 's/.*\.swift[ `]+//')
count=0
for name in $tests; do
    count=$((count + 1))
    if ! grep -rqE "func $name[ (]" "$pp" "$root/Packages/VisualCore/Tests" "$root/Packages/VisualCoreRendering/Tests" "$root/Apps/VisualCore/Tests" 2>/dev/null; then
        echo "PROBLEM: proving test '$name' named in store-listing.md does not exist"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
