#!/bin/sh
# scan-claims-release.sh — feature 080 (A10-P06) T-A10-607 (FR-A10-621; SC-A10-603; clarification 2). Two checks:
# 1. The store text and the interface Swift of Neon Arcade contain none of the skill, benefit and ranking words
#    (whole words, case-insensitive).
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Neon Arcade package, the VisualCore packages or the app's tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/neon-arcade/store-listing.md"
swift="$root/Packages/ExperiencesCreative/NeonArcade/Experience/ArcadeControls.swift $root/Packages/ExperiencesCreative/NeonArcade/Experience/ArcadePresenter.swift $root/Packages/ExperiencesCreative/NeonArcade/Core/ArcadeAnnouncements.swift"
problems=0
for word in skill skills reflex reflexes "reaction time" cognitive brain health therapy "improve your" "train your" leaderboard "rank among" "compete with" "world record"; do
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
    if ! grep -rqE "func $name[ (]" "$root/Packages/ExperiencesCreative/NeonArcade" "$root/Packages/VisualCore/Tests" "$root/Packages/VisualCoreRendering/Tests" "$root/Apps/VisualCore/Tests" 2>/dev/null; then
        echo "PROBLEM: proving test '$name' named in store-listing.md does not exist"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
