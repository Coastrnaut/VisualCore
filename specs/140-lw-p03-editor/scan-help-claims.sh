#!/bin/sh
# scan-help-claims.sh — feature 140 (A19-P03) T-A19-308 (FR-A19-304; SC-A19-304; clarification Q4). Beside the
# platform scan of feature 138, refuses in the Living Wallpapers sources, case-insensitively, the claims that the
# experience does the system's part: "automatically", "sets your wallpaper", "installs" and "animated wallpaper". The
# help says the person sets the wallpaper through the system's own controls. Exits 1 with the matching lines when one
# is found, 0 otherwise. Run from the repository root.
set -u
dir="Packages/ExperiencesCreative/LivingWallpapers"
if [ ! -d "$dir" ]; then echo "FAIL: $dir is missing"; exit 1; fi
words='automatically|sets your wallpaper|installs|animated wallpaper'
if grep -rniE "$words" "$dir"; then echo "FAIL: refused claim found in $dir"; exit 1; fi
files=$(find "$dir" -type f | wc -l | tr -d ' ')
echo "PASS: no refused claim in $files files of $dir"
