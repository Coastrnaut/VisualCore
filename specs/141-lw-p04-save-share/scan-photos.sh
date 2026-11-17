#!/bin/sh
# scan-photos.sh — feature 141 (A19-P04) T-A19-404 (FR-A19-402; SC-A19-401; clarification Q1). Saving goes through
# the system share sheet with the app's add-only usage string; the experience never reads the photo library or saves
# to it itself. Refuses in the Living Wallpapers sources an import of the Photos framework, PHPhotoLibrary, PHAsset and
# UIImageWriteToSavedPhotosAlbum. Exits 1 with the matching lines when one is found, 0 otherwise. Run from the
# repository root.
set -u
dir="Packages/ExperiencesCreative/LivingWallpapers"
if [ ! -d "$dir" ]; then echo "FAIL: $dir is missing"; exit 1; fi
pattern='import Photos|PHPhotoLibrary|PHAsset|UIImageWriteToSavedPhotosAlbum'
if grep -rnE "$pattern" "$dir" --include='*.swift'; then echo "FAIL: photo library access found in $dir"; exit 1; fi
files=$(find "$dir" -name '*.swift' | wc -l | tr -d ' ')
echo "PASS: no photo library access in $files Swift files of $dir"
