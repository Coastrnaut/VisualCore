#!/bin/sh
# scan-sources-release.sh — feature 136 (A18-P06) T-A18-603 (FR-A18-602; SC-A18-601; clarification Q3).
# Modelled on specs/129-ia-p06-release/scan-sources-release.sh. Refuses, in the Ambient Clock sources, every network,
# tracking, sensor, recording, photo-library and image-picker use of clarification Q3 and any brightness write, and
# requires the idle-timer property in exactly one file, Experience/KeepAwake.swift (the opt-in keep-awake).
# Exits 1 with the matching lines when one is found, 0 otherwise. Run from the repository root.
set -u
dir="Packages/ExperiencesCreative/AmbientClock"
keep="$dir/Experience/KeepAwake.swift"
pattern='URLSession|import Network|CLLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|PHPhotoLibrary|UIImagePickerController|ASIdentifierManager|AppTrackingTransparency|brightness *='
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "FAIL: scanned uses found in $dir"
    exit 1
fi
idle=$(grep -rlE 'isIdleTimerDisabled' "$dir" --include='*.swift')
if [ "$idle" != "$keep" ]; then
    echo "FAIL: the idle-timer property must appear in exactly $keep; found in: ${idle:-no file}"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no scanned use in $files Swift files of $dir; the idle timer only in $keep"
