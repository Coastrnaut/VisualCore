#!/bin/sh
# scan-claims-release.sh — feature 143 (A19-P06) T-A19-607 (FR-A19-605; SC-A19-603; clarification Q2). Modelled on
# specs/136-ac-p06-release/scan-claims-release.sh. Two checks:
# 1. The store text and the interface Swift of Living Wallpapers (controls, editor model, help view and the adapter's
#    words) contain none of the refused words: live wallpaper, animated wallpaper, set as wallpaper, sets your
#    wallpaper, automatically, installs, video, unlimited, 8k, any size, fps, real-time and lossless. Words are matched
#    whole and case-insensitively. The whole file is scanned, comments included.
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Living Wallpapers package, every test file named there exists as a class or struct of that name, and every interface
#    test class named in the store text exists in the app's interface tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/living-wallpapers/store-listing.md"
me="$root/Packages/ExperiencesCreative/LivingWallpapers"
ui="$root/Apps/VisualCore/Tests/UI/LivingWallpapers"
swift="$me/Experience/WallpaperControls.swift $me/Experience/EditorModel.swift $me/Experience/HelpView.swift $me/Experience/Adapter/WallpaperCore.swift"
problems=0
for file in "$store" $swift; do
    if [ ! -f "$file" ]; then echo "PROBLEM: ${file#$root/} is missing"; echo "FAIL: claims scan"; exit 1; fi
done
words='live wallpaper|animated wallpaper|set as wallpaper|sets your wallpaper|automatically|installs|video|unlimited|8k|any size|fps|real-time|lossless'
for file in "$store" $swift; do
    hits=$(grep -n '' "$file" | grep -iwE "$words")
    if [ -n "$hits" ]; then
        printf '%s\n' "$hits" | while IFS= read -r line; do echo "PROBLEM: refused claim in ${file#$root/}: $line"; done
        problems=$((problems + 1))
    fi
done
pairs=$(grep -E '^\|' "$store" | grep -oE '[A-Za-z0-9]+\.swift[ `]+[A-Za-z_][A-Za-z0-9_]*' | sed -E 's/\.swift[ `]+/ /')
count=0
for name in $(printf '%s\n' "$pairs" | awk '{print $2}'); do
    count=$((count + 1))
    if ! grep -rqE "func $name[ (]" "$me" 2>/dev/null; then
        echo "PROBLEM: proving test '$name' named in store-listing.md does not exist in ${me#$root/}"
        problems=$((problems + 1))
    fi
done
for suite in $(printf '%s\n' "$pairs" | awk '{print $1}' | sort -u); do
    if [ -z "$suite" ]; then continue; fi
    if ! grep -rqE "(class|struct) $suite[ :{]" "$me/CoreTests" "$me/ExperienceTests" 2>/dev/null; then
        echo "PROBLEM: test suite '$suite' named in store-listing.md does not exist in ${me#$root/}"
        problems=$((problems + 1))
    fi
done
for class in $(grep -oE 'LW[A-Za-z]+UITests' "$store" | sort -u); do
    if ! grep -rqE "class $class[ :]" "$ui" 2>/dev/null; then
        echo "PROBLEM: interface test class '$class' named in store-listing.md does not exist in ${ui#$root/}"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
