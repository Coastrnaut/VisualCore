#!/bin/sh
# scan-claims-release.sh — feature 122 (A16-P06) T-A16-607 (FR-A16-621; SC-A16-603; clarification Q2). Modelled on
# specs/115-me-p06-release/scan-claims-release.sh. Two checks:
# 1. The store text and the interface Swift of Simulation Lab (controls, presenter, legend, the adapter's words)
#    contain none of the refused words (accurate, accuracy, precise, precision, predict, prediction, forecast,
#    certified, certification, real-time, realistic, scientific-grade, fps, frames per second, battery, a millisecond
#    figure; whole words, case-insensitive). "exact" is allowed: the automaton's states are exact. The phrase
#    "half-precision", the storage format the approximation label names, is removed before matching. The whole file is
#    scanned, comments included.
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function
#    (`func testName` of XCTest or `@Test func testName` of Swift Testing) in the Simulation Lab package, every
#    test file named there exists as a class or struct of that name, and every interface test class named in the store
#    text exists in the app's interface tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/simulation-lab/store-listing.md"
me="$root/Packages/ExperiencesCreative/SimulationLab"
ui="$root/Apps/VisualCore/Tests/UI/SimulationLab"
swift="$me/Experience/SimulationControls.swift $me/Experience/SimulationPresenter.swift $me/Experience/SimulationLegend.swift $me/Experience/Adapter/SimulationCore.swift"
problems=0
for file in "$store" $swift; do
    if [ ! -f "$file" ]; then echo "PROBLEM: ${file#$root/} is missing"; echo "FAIL: claims scan"; exit 1; fi
done
words='accurate|accuracy|precise|precision|predict|prediction|forecast|certified|certification|real-time|realistic|scientific-grade|fps|frames per second|battery|[0-9]+([.,][0-9]+)? ?ms'
for file in "$store" $swift; do
    hits=$(grep -n '' "$file" | sed -E 's/half-precision//g' | grep -iwE "$words")
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
for class in $(grep -oE 'SL[A-Za-z]+UITests' "$store" | sort -u); do
    if ! grep -rqE "class $class[ :]" "$ui" 2>/dev/null; then
        echo "PROBLEM: interface test class '$class' named in store-listing.md does not exist in ${ui#$root/}"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
