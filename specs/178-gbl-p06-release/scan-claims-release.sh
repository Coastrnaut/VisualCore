#!/bin/sh
# scan-claims-release.sh — feature 178 (A24-P06) T-A24-607 (FR-A24-605; SC-A24-603; clarification Q2 on the claims
# words). Modelled on specs/171-vpl-p06-release/scan-claims-release.sh. Three checks:
# 1. The store text and the interface Swift of Graphics Benchmark Lab (controls, results view, repeatability view,
#    presenter and the adapter) contain none of the refused words: rank, ranking, ranked, leaderboard, score, scores,
#    fastest, slowest, faster than, slower than, scientific, lab-grade, certified, accurate, accuracy, precise,
#    precision, Geekbench, 3DMark, GFXBench, AnTuTu, Android, upload, cloud, sync, account, fps, unlimited, real-time
#    and overclock. Words are matched whole and case-insensitively; the whole file is scanned, comments included. The
#    required phrase "does not rank devices" is removed from each line before matching. The explanation
#    (GBLExplanation, ExplanationView) is not scanned here: it states these limits as negations and stays under the
#    shared copy check.
# 2. The store text contains the phrase "does not rank devices".
# 3. Every proving test named in the store text's claim table ("File.swift testName") exists as a function in the
#    Graphics Benchmark Lab package, every test file named there exists as a class or struct of that name in its
#    CoreTests or ExperienceTests, and every interface test class named in the store text exists in the app's
#    interface tests.
# STORE=path overrides the store text (for testing this script). Prints PASS or one PROBLEM line per finding and
# FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="${STORE:-$root/docs/apps/graphics-benchmark-lab/store-listing.md}"
me="$root/Packages/ExperiencesCreative/GraphicsBenchmarkLab"
ui="$root/Apps/VisualCore/Tests/UI/GraphicsBenchmarkLab"
swift="$me/Experience/GBLControls.swift $me/Experience/ResultsView.swift $me/Experience/RepeatabilityView.swift $me/Experience/BenchPresenter.swift $me/Experience/Adapter/BenchCore.swift"
problems=0
for file in "$store" $swift; do
    if [ ! -f "$file" ]; then echo "PROBLEM: ${file#$root/} is missing"; echo "FAIL: claims scan"; exit 1; fi
done
words='rank|ranking|ranked|leaderboard|score|scores|fastest|slowest|faster than|slower than|scientific|lab-grade|certified|accurate|accuracy|precise|precision|geekbench|3dmark|gfxbench|antutu|android|upload|cloud|sync|account|fps|unlimited|real-time|overclock'
for file in "$store" $swift; do
    # Lower-case each line (portable case-insensitive removal), drop the exempt phrase, then match whole words.
    hits=$(awk '{ l = tolower($0); gsub(/does not rank devices/, "", l); print NR ":" l }' "$file" | grep -iwE "$words" | cut -d: -f1)
    if [ -n "$hits" ]; then
        for n in $hits; do echo "PROBLEM: refused claim in ${file#$root/}:$n: $(sed -n "${n}p" "$file")"; done
        problems=$((problems + 1))
    fi
done
if ! grep -qi 'does not rank devices' "$store"; then
    echo "PROBLEM: the phrase 'does not rank devices' is missing from ${store#$root/}"
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
for class in $(grep -oE 'GBL[A-Za-z]+UITests' "$store" | sort -u); do
    if ! grep -rqE "class $class[ :]" "$ui" 2>/dev/null; then
        echo "PROBLEM: interface test class '$class' named in store-listing.md does not exist in ${ui#$root/}"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
