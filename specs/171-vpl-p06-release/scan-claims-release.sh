#!/bin/sh
# scan-claims-release.sh — feature 171 (A23-P06) T-A23-607 (FR-A23-605; SC-A23-603; clarification Q on the claims
# words). Modelled on specs/164-ss-p06-release/scan-claims-release.sh. Three checks:
# 1. The store text and the interface Swift of Visual Programming Lab (controls, canvas overlay, library view,
#    presenter and the adapter's words) contain none of the refused words: programming language, write code, coding,
#    script, scripting, type shaders, shader code editor, Shadertoy, TouchDesigner, Blender, Unreal, Unity,
#    node-based compositor, compatible with, imports, educational, teaches, learn to code, scientific, upload, export,
#    cloud, sync, account, share, fps, unlimited and real-time. Words are matched whole and case-insensitively. The
#    whole file is scanned, comments included.
# 2. The store text contains the phrase "no code to type".
# 3. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Visual Programming Lab package, every test file named there exists as a class or struct of that name, and every
#    interface test class named in the store text exists in the app's interface tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/visual-programming-lab/store-listing.md"
me="$root/Packages/ExperiencesCreative/VisualProgrammingLab"
ui="$root/Apps/VisualCore/Tests/UI/VisualProgrammingLab"
swift="$me/Experience/LabControls.swift $me/Experience/CanvasOverlay.swift $me/Experience/LabLibraryView.swift $me/Experience/LabPresenter.swift $me/Experience/Adapter/LabCore.swift"
problems=0
for file in "$store" $swift; do
    if [ ! -f "$file" ]; then echo "PROBLEM: ${file#$root/} is missing"; echo "FAIL: claims scan"; exit 1; fi
done
words='programming language|write code|coding|script|scripting|type shaders|shader code editor|Shadertoy|TouchDesigner|Blender|Unreal|Unity|node-based compositor|compatible with|imports|educational|teaches|learn to code|scientific|upload|export|cloud|sync|account|share|fps|unlimited|real-time'
for file in "$store" $swift; do
    hits=$(grep -n '' "$file" | grep -iwE "$words")
    if [ -n "$hits" ]; then
        printf '%s\n' "$hits" | while IFS= read -r line; do echo "PROBLEM: refused claim in ${file#$root/}: $line"; done
        problems=$((problems + 1))
    fi
done
if ! grep -q 'no code to type' "$store"; then
    echo "PROBLEM: the phrase 'no code to type' is missing from ${store#$root/}"
    problems=$((problems + 1))
fi
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
for class in $(grep -oE 'VPL[A-Za-z]+UITests' "$store" | sort -u); do
    if ! grep -rqE "class $class[ :]" "$ui" 2>/dev/null; then
        echo "PROBLEM: interface test class '$class' named in store-listing.md does not exist in ${ui#$root/}"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
