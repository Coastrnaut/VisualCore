#!/bin/sh
# scan-claims-release.sh — feature 101 (A13-P06) T-A13-607 (FR-A13-621; SC-A13-603; clarification Q2). Modelled on
# specs/094-tw-p06-release/scan-claims-release.sh. Two checks:
# 1. The store text and the interface Swift of Light Maze (controls, presenter) contain none of the refused words
#    (physics, physical, optics, optical, accurate, accuracy, precise, precision, scientific, realistic, fps, frames per
#    second, battery, a millisecond figure; whole words, case-insensitive).
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Light Maze package, the VisualCore packages or the app's tests, and every interface test class named there exists.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/light-maze/store-listing.md"
lm="$root/Packages/ExperiencesCreative/LightMaze"
swift="$lm/Experience/MazeControls.swift $lm/Experience/MazePresenter.swift"
problems=0
if [ ! -f "$store" ]; then echo "PROBLEM: $store is missing"; echo "FAIL: claims scan"; exit 1; fi
words='physics|physical|optics|optical|accurate|accuracy|precise|precision|scientific|realistic|fps|frames per second|battery|[0-9]+([.,][0-9]+)? ?ms'
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
    if ! grep -rqE "func $name[ (]" "$lm" "$root/Packages/VisualCore/Tests" "$root/Packages/VisualCoreRendering/Tests" "$root/Apps/VisualCore/Tests" 2>/dev/null; then
        echo "PROBLEM: proving test '$name' named in store-listing.md does not exist"
        problems=$((problems + 1))
    fi
done
for class in $(grep -oE 'LM[A-Za-z]+UITests' "$store" | sort -u); do
    if ! grep -rqE "class $class[ :]" "$root/Apps/VisualCore/Tests/UI/LightMaze" 2>/dev/null; then
        echo "PROBLEM: interface test class '$class' named in store-listing.md does not exist"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
