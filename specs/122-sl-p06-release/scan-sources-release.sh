#!/bin/sh
# scan-sources-release.sh — feature 122 (A16-P06) T-A16-603 (FR-A16-601; SC-A16-601; clarification Q3).
# Modelled on specs/115-me-p06-release/scan-sources-release.sh. Refuses, in the Simulation Lab sources, every
# network, tracking, sensor, recording, photo-library, image-picker, brightness and idle-timer use of clarification Q3.
# Exits 1 with the matching lines when one is found, 0 otherwise. Run from the repository root.
set -u
dir="Packages/ExperiencesCreative/SimulationLab"
pattern='URLSession|import Network|CLLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|PHPhotoLibrary|UIImagePickerController|ASIdentifierManager|AppTrackingTransparency|UIScreen\.main\.brightness|isIdleTimerDisabled'
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "FAIL: scanned uses found in $dir"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no scanned use in $files Swift files of $dir"
