#!/bin/sh
# scan-sources-release.sh — feature 143 (A19-P06) T-A19-603 (FR-A19-602; SC-A19-601; clarification Q3).
# Modelled on specs/136-ac-p06-release/scan-sources-release.sh. Refuses, in the Living Wallpapers sources, every
# network, tracking, sensor, recording, Photos-library and image-picker use of clarification Q3, the idle-timer
# property and any brightness write. Files leave the experience only through the system share sheet, whose Save Image
# uses the app's add-only usage string; the experience itself never touches the library.
# Exits 1 with the matching lines when one is found, 0 otherwise. Run from the repository root.
set -u
dir="Packages/ExperiencesCreative/LivingWallpapers"
pattern='URLSession|import Network|CLLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|PHPhotoLibrary|import Photos|PhotosUI|UIImagePickerController|ASIdentifierManager|AppTrackingTransparency|isIdleTimerDisabled|brightness *='
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "FAIL: scanned uses found in $dir"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no scanned use in $files Swift files of $dir"
