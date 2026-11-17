#!/bin/sh
# scan-platform-claims.sh — feature 138 (A19-P01) T-A19-110 (FR-A19-106; SC-A19-105; clarification Q5). The guard of
# the short-loop decision (docs/apps/living-wallpapers/video-decision.md: no-go for version 0.1) and of the platform
# truth rule (constitution A19): refuses, in the Living Wallpapers sources, a movie encoder (AVAssetWriter,
# VideoToolbox, CVPixelBuffer), a screen brightness write, and, case-insensitively, the words "live wallpaper",
# "video" and "set as wallpaper". Exits 1 with the matching lines when one is found, 0 otherwise. Run from the
# repository root.
set -u
dir="Packages/ExperiencesCreative/LivingWallpapers"
if [ ! -d "$dir" ]; then echo "FAIL: $dir is missing"; exit 1; fi
apis='AVAssetWriter|VideoToolbox|CVPixelBuffer|UIScreen\.main\.brightness'
words='live wallpaper|video|set as wallpaper'
found=0
if grep -rnE "$apis" "$dir"; then found=1; fi
if grep -rniE "$words" "$dir"; then found=1; fi
if [ "$found" -ne 0 ]; then echo "FAIL: refused API or word found in $dir"; exit 1; fi
files=$(find "$dir" -type f | wc -l | tr -d ' ')
echo "PASS: no refused API or word in $files files of $dir"
