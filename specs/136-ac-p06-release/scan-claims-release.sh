#!/bin/sh
# scan-claims-release.sh — feature 136 (A18-P06) T-A18-607 (FR-A18-605; SC-A18-603; clarification Q2). Modelled on
# specs/129-ia-p06-release/scan-claims-release.sh. Two checks:
# 1. The store text and the interface Swift of Ambient Clock (controls, overlay, presenter and the adapter's words)
#    contain none of the refused words: accurate, accuracy, atomic, precise, precision, exact time, synchronized,
#    synced, always on, always-on, never sleeps, screen stays on, burn-in proof, burn-in free, weather, forecast,
#    temperature, location, fps, real-time, low power and energy-saving. Words are matched whole and
#    case-insensitively. The whole file is scanned, comments included.
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Ambient Clock package, every test file named there exists as a class or struct of that name, and every interface
#    test class named in the store text exists in the app's interface tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/ambient-clock/store-listing.md"
me="$root/Packages/ExperiencesCreative/AmbientClock"
ui="$root/Apps/VisualCore/Tests/UI/AmbientClock"
swift="$me/Experience/AmbientControls.swift $me/Experience/ClockOverlay.swift $me/Experience/AmbientPresenter.swift $me/Experience/Adapter/AmbientCore.swift"
problems=0
for file in "$store" $swift; do
    if [ ! -f "$file" ]; then echo "PROBLEM: ${file#$root/} is missing"; echo "FAIL: claims scan"; exit 1; fi
done
words='accurate|accuracy|atomic|precise|precision|exact time|synchronized|synced|always on|always-on|never sleeps|screen stays on|burn-in proof|burn-in free|weather|forecast|temperature|location|fps|real-time|low power|energy-saving'
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
for class in $(grep -oE 'AC[A-Za-z]+UITests' "$store" | sort -u); do
    if ! grep -rqE "class $class[ :]" "$ui" 2>/dev/null; then
        echo "PROBLEM: interface test class '$class' named in store-listing.md does not exist in ${ui#$root/}"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
