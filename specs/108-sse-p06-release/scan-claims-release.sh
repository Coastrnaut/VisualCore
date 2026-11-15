#!/bin/sh
# scan-claims-release.sh — feature 108 (A14-P06) T-A14-608 (FR-A14-621; SC-A14-603; clarification Q2). Modelled on
# specs/101-lm-p06-release/scan-claims-release.sh. Two checks:
# 1. The store text and the interface Swift of Solar System Explorer (controls, presenter) contain none of the refused
#    words (ephemeris, real-time, live sky, telescope, precise, precision, accurate, accuracy, exact positions, fps,
#    frames per second, battery, a millisecond figure; whole words, case-insensitive). The one allowed use of
#    "ephemeris" is the exact phrase "not an ephemeris", also when a line break (and a `//` comment marker) falls
#    inside it; every other use is refused.
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function
#    (`func testName` of XCTest or `@Test func testName` of Swift Testing) in the Solar System Explorer package, every
#    test file named there exists as a class or struct of that name, and every interface test class named in the store
#    text exists in the app's interface tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/solar-system-explorer/store-listing.md"
sse="$root/Packages/ExperiencesCreative/SolarSystemExplorer"
ui="$root/Apps/VisualCore/Tests/UI/SolarSystemExplorer"
swift="$sse/Experience/SolarControls.swift $sse/Experience/SolarPresenter.swift"
problems=0
for file in "$store" $swift; do
    if [ ! -f "$file" ]; then echo "PROBLEM: ${file#$root/} is missing"; echo "FAIL: claims scan"; exit 1; fi
done
words='ephemeris|real-time|live sky|telescope|precise|precision|accurate|accuracy|exact positions|fps|frames per second|battery|[0-9]+([.,][0-9]+)? ?ms'
for file in "$store" $swift; do
    # Mask the allowed phrase "not an ephemeris" (line breaks and comment markers kept, so line numbers stay true).
    hits=$(perl -0pe 's{\b(not)((?:\s|//)+)(an)((?:\s|//)+)ephemeris\b}{$1$2$3$4---------}gi' "$file" \
        | grep -n '' | grep -iwE "$words")
    if [ -n "$hits" ]; then
        printf '%s\n' "$hits" | while IFS= read -r line; do echo "PROBLEM: refused claim in ${file#$root/}: $line"; done
        problems=$((problems + 1))
    fi
done
pairs=$(grep -E '^\|' "$store" | grep -oE '[A-Za-z0-9]+\.swift[ `]+[A-Za-z_][A-Za-z0-9_]*' | sed -E 's/\.swift[ `]+/ /')
count=0
files=""
for name in $(printf '%s\n' "$pairs" | awk '{print $2}'); do
    count=$((count + 1))
    if ! grep -rqE "func $name[ (]" "$sse" 2>/dev/null; then
        echo "PROBLEM: proving test '$name' named in store-listing.md does not exist in ${sse#$root/}"
        problems=$((problems + 1))
    fi
done
for suite in $(printf '%s\n' "$pairs" | awk '{print $1}' | sort -u); do
    if [ -z "$suite" ]; then continue; fi
    if ! grep -rqE "(class|struct) $suite[ :{]" "$sse/CoreTests" "$sse/ExperienceTests" 2>/dev/null; then
        echo "PROBLEM: test suite '$suite' named in store-listing.md does not exist in ${sse#$root/}"
        problems=$((problems + 1))
    fi
done
for class in $(grep -oE 'SSE[A-Za-z]+UITests' "$store" | sort -u); do
    if ! grep -rqE "class $class[ :]" "$ui" 2>/dev/null; then
        echo "PROBLEM: interface test class '$class' named in store-listing.md does not exist in ${ui#$root/}"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
