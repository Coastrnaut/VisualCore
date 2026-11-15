#!/bin/sh
# scan-sources-release.sh — feature 108 (A14-P06) T-A14-603 (FR-A14-601, FR-A14-602; SC-A14-601; clarification Q3).
# Refuses, in the Solar System Explorer sources, every network, tracking, sensor, recording, brightness and idle-timer
# use of clarification Q3. Exits 1 with the matching lines when one is found, 0 otherwise. Run from the repository root.
set -u
dir="Packages/ExperiencesCreative/SolarSystemExplorer"
pattern='URLSession|import Network|CLLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|ASIdentifierManager|AppTrackingTransparency|UIScreen\.main\.brightness|isIdleTimerDisabled'
if grep -rnE "$pattern" "$dir" --include='*.swift'; then
    echo "FAIL: scanned uses found in $dir"
    exit 1
fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no scanned use in $files Swift files of $dir"
