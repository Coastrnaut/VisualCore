# Contract: Living Wallpapers core (A19-P01)

- **Catalog:** 4 scenes; each has 2–3 parameters (minimum < maximum, minimum ≤ default ≤ maximum) and 3 presets of 4
  opaque colours; the ids are unique.
- **Templates:** 9 templates with the sizes of clarification Q3; landscape swaps the edges; every template has a
  provenance record.
- **Project:**
  - the round trip is exact;
  - each of the 7 refusals comes from one sample;
  - a refused file leaves `WallpaperProject.default` (aurora-bands, preset 0, seed 1, iphone-16-pro, portrait, time 0,
    png).
- **Planner:**
  - with maxEdge ≥ the template's long edge, the plan is the exact template size;
  - with maxEdge 2048, 4096 and 8192, every template above the limit is refused before allocation, and its offered
    size equals `ExportGeometry(maxEdge:).size(longEdge:aspect:)`, which fits;
  - with maxEdge 0 the result is `noLimit`.
- **Fixture:** for every template and orientation that fits 4096, the encoded file inspects to the planned width and
  height and the profile `kCGColorSpaceSRGB`, with 0 mismatches.
- **Scan:** `scan-platform-claims.sh` exits 0, finding no `AVAssetWriter`, `VideoToolbox`, `CVPixelBuffer`, "live
  wallpaper", "video" or "set as wallpaper" in `Packages/ExperiencesCreative/LivingWallpapers`.
