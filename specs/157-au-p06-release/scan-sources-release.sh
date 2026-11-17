#!/bin/sh
# scan-sources-release.sh — feature 157 (A21-P06) T-A21-603 (FR-A21-602; SC-A21-601; clarification Q3).
# Modelled on specs/150-zg-p06-release/scan-sources-release.sh. Refuses, in the Aurora sources, every network,
# location, tracking, sensor, recording, camera, contacts and Photos use of clarification Q3, the idle-timer property
# and any brightness write. The optional sound uses the audio output only (the ambient loop player), never the input.
# Exits 1 with the matching lines when one is found, 0 otherwise. Run from the repository root.
set -u
dir="Packages/ExperiencesCreative/Aurora"
pattern='URLSession|import Network|CLLocation|import CoreLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|PHPhotoLibrary|import Photos|PhotosUI|ASIdentifierManager|AppTrackingTransparency|isIdleTimerDisabled|brightness *='
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "FAIL: scanned uses found in $dir"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no scanned use in $files Swift files of $dir"
