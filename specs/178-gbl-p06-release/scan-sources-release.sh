#!/bin/sh
# scan-sources-release.sh — feature 178 (A24-P06) T-A24-603 (FR-A24-602; SC-A24-601; clarification Q3 on the source
# scan). Modelled on specs/171-vpl-p06-release/scan-sources-release.sh. Refuses, in the Graphics Benchmark Lab sources,
# every network, location, sensor, recording, contacts, Photos and tracking use of the clarification, the vendor
# identifier, the device's name, the idle-timer property, any brightness write and the pasteboard. ShareLink is refused
# in every file except Experience/ResultsView.swift, where it must appear. Whole files are scanned, comments included.
# Prints PASS, or the matching lines with PROBLEM lines and FAIL; exits 1 on any finding, 0 otherwise. Run from the
# repository root.
set -u
dir="Packages/ExperiencesCreative/GraphicsBenchmarkLab"
share="$dir/Experience/ResultsView.swift"
pattern='URLSession|import Network|CLLocation|import CoreLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|PHPhotoLibrary|import Photos|PhotosUI|ASIdentifierManager|AppTrackingTransparency|identifierForVendor|UIDevice\.current\.name|isIdleTimerDisabled|brightness *=|UIPasteboard'
problems=0
if [ ! -d "$dir" ] || [ ! -f "$share" ]; then
    echo "PROBLEM: $dir or $share is missing"
    echo "FAIL: source scan"
    exit 1
fi
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "PROBLEM: scanned uses found in $dir"
    problems=$((problems + 1))
fi
others=$(grep -rln 'ShareLink' "$dir" --include='*.swift' | grep -vxF "$share")
if [ -n "$others" ]; then
    printf '%s\n' "$others" | while IFS= read -r file; do
        grep -n 'ShareLink' "$file" | sed "s|^|$file:|"
        echo "PROBLEM: ShareLink outside $share in $file"
    done
    problems=$((problems + 1))
fi
if ! grep -q 'ShareLink' "$share"; then
    echo "PROBLEM: ShareLink is missing from $share"
    problems=$((problems + 1))
fi
if [ "$problems" -gt 0 ]; then
    echo "FAIL: source scan, $problems problems"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no scanned use in $files Swift files of $dir; ShareLink only in $share"
