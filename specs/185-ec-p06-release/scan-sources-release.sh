#!/bin/sh
# scan-sources-release.sh — feature 185 (A25-P06) T-A25-603 (contracts/release.md; clarification Q3 on the source
# scan). Modelled on specs/178-gbl-p06-release/scan-sources-release.sh. Refuses, in the Effects Composer sources, every
# network, location, sensor, recording, contacts, Photos-library and tracking use of the clarification, the vendor
# identifier, the device's name, the idle-timer property, any brightness write and the pasteboard. Whole files are
# scanned for these, comments included. "import Photos" is matched only when not followed by "U", so the picker's
# "import PhotosUI" is not taken for the Photos library framework.
# PhotosUI, PhotosPicker and ShareLink are refused in every file except Experience/ECControls.swift, where each must
# appear. For these three names only, lines that are wholly "//" comments are skipped outside ECControls.swift: a
# documentation comment naming the API (StillExport.swift says its file is handed to ShareLink) is not a use.
# Prints PASS, or the matching lines with PROBLEM lines and FAIL; exits 1 on any finding, 0 otherwise. Run from the
# repository root.
set -u
dir="Packages/ExperiencesCreative/EffectsComposer"
controls="$dir/Experience/ECControls.swift"
pattern='URLSession|import Network|CLLocation|import CoreLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|PHPhotoLibrary|import Photos([^U]|$)|ASIdentifierManager|AppTrackingTransparency|identifierForVendor|UIDevice\.current\.name|isIdleTimerDisabled|brightness *=|UIPasteboard'
problems=0
if [ ! -d "$dir" ] || [ ! -f "$controls" ]; then
    echo "PROBLEM: $dir or $controls is missing"
    echo "FAIL: source scan"
    exit 1
fi
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "PROBLEM: scanned uses found in $dir"
    problems=$((problems + 1))
fi
for name in PhotosUI PhotosPicker ShareLink; do
    others=$(grep -rn "$name" "$dir" --include='*.swift' | grep -v "^$controls:" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//')
    if [ -n "$others" ]; then
        printf '%s\n' "$others"
        echo "PROBLEM: $name outside $controls"
        problems=$((problems + 1))
    fi
    if ! grep -q "$name" "$controls"; then
        echo "PROBLEM: $name is missing from $controls"
        problems=$((problems + 1))
    fi
done
if [ "$problems" -gt 0 ]; then
    echo "FAIL: source scan, $problems problems"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no scanned use in $files Swift files of $dir; PhotosUI, PhotosPicker and ShareLink only in $controls"
