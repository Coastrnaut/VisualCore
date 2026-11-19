#!/bin/sh
# scan-sources-release.sh — feature 171 (A23-P06) T-A23-603 (FR-A23-602; SC-A23-601; clarification Q on the source
# scan). Modelled on specs/164-ss-p06-release/scan-sources-release.sh. Refuses, in the Visual Programming Lab sources,
# every network, location, tracking, sensor, recording, camera, contacts and Photos use of the clarification, the
# idle-timer property, any brightness write, the pasteboard and the share sheet (UIPasteboard, ShareLink).
# Exits 1 with the matching lines when one is found, 0 otherwise. Run from the repository root.
set -u
dir="Packages/ExperiencesCreative/VisualProgrammingLab"
pattern='URLSession|import Network|CLLocation|import CoreLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|PHPhotoLibrary|import Photos|PhotosUI|ASIdentifierManager|AppTrackingTransparency|isIdleTimerDisabled|brightness *=|UIPasteboard|ShareLink'
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "FAIL: scanned uses found in $dir"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no scanned use in $files Swift files of $dir"
