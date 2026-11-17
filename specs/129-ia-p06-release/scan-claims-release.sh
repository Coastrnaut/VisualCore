#!/bin/sh
# scan-claims-release.sh — feature 129 (A17-P06) T-A17-607 (FR-A17-605; SC-A17-603; clarification Q2). Modelled on
# specs/122-sl-p06-release/scan-claims-release.sh. Two checks:
# 1. The store text and the interface Swift of Interactive Anatomy (controls, presenter, overlay, the adapter's words
#    and AnatomyReview) contain none of the refused words: diagnose, diagnosis, diagnostic, treatment, cure, symptom,
#    symptoms, therapy, medical advice, accurate, accuracy, precise, certified, certification, anatomically correct,
#    realistic, lifelike, real-time, fps, frames per second, battery and a millisecond figure. Words are matched whole
#    and case-insensitively. "clinician" stays allowed: the not-reviewed sentence names one. The whole file is
#    scanned, comments included.
# 2. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Interactive Anatomy package, every test file named there exists as a class or struct of that name, and every
#    interface test class named in the store text exists in the app's interface tests.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="$root/docs/apps/interactive-anatomy/store-listing.md"
me="$root/Packages/ExperiencesCreative/InteractiveAnatomy"
ui="$root/Apps/VisualCore/Tests/UI/InteractiveAnatomy"
swift="$me/Experience/AnatomyControls.swift $me/Experience/AnatomyPresenter.swift $me/Experience/AnatomyOverlay.swift $me/Experience/Adapter/AnatomyCore.swift $me/Core/AnatomyReview.swift"
problems=0
for file in "$store" $swift; do
    if [ ! -f "$file" ]; then echo "PROBLEM: ${file#$root/} is missing"; echo "FAIL: claims scan"; exit 1; fi
done
words='diagnose|diagnosis|diagnostic|treatment|cure|symptom|symptoms|therapy|medical advice|accurate|accuracy|precise|certified|certification|anatomically correct|realistic|lifelike|real-time|fps|frames per second|battery|[0-9]+([.,][0-9]+)? ?ms'
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
for class in $(grep -oE 'IA[A-Za-z]+UITests' "$store" | sort -u); do
    if ! grep -rqE "class $class[ :]" "$ui" 2>/dev/null; then
        echo "PROBLEM: interface test class '$class' named in store-listing.md does not exist in ${ui#$root/}"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
