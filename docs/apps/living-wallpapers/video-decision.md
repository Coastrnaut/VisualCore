# Living Wallpapers — short-loop export decision (A19-P01, feature 138)

Gap G-VIDEO of the Phase 00 contract. Decided on 2026-11-17 in clarification Q5 of
`specs/138-lw-p01-export-contract/spec.md` (FR-A19-106).

## Decision

**No-go for version 0.1.** Living Wallpapers exports still images only. A short looping export is not built in this
version.

## Public interface assessed

AVFoundation's asset writer (`AVAssetWriter`) with a pixel buffer adaptor, fed frame by frame by the offscreen render
of VisualCore, `RenderHost.renderOffscreen(width:height:time:)` in
`Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderHost.swift`. That function returns a `StillImage` and
asserts the main thread (`Self.assertMainThread()`) before it draws.

## Cost bounds

These are bounds by arithmetic, not measurements:
- a 10-second loop at 30 frames per second is 300 offscreen renders and 300 frame encodes;
- every one of the 300 renders runs on the main thread, because `renderOffscreen` asserts it, so the interface would
  stall while the loop is produced;
- each frame at a template size (for example 1320×2868) is a full-resolution RGBA image copied from the GPU before it
  reaches the encoder.

## Why it is not decided go

The manual accepts a short export only after encoder and resource feasibility is shown. The costs that decide
feasibility are disk use and heat, and both can be measured only on devices. No install, launch or test of the
unified app on a device happens before `ImplementationLock-100` is recorded, so feasibility cannot be shown in this
phase. Simulator results would not count as device evidence.

## Owner if reopened

If a later round reopens the question, the owner is VisualCore: the encoder belongs in `VisualCoreRendering` as one
common encoder used by every exporter, not in the experience. Reopening needs the device measurements of disk and
heat cost, a progress and cancel policy, and a release blocker condition.

## Consequence for version 0.1

There is no control, copy or code for a looping export in version 0.1. The help text may still explain how a person
applies an exported image through the system's own controls.

This records the manual's feature 04 (§2, "Short optional video export only after encoder/resource feasibility is
demonstrated") and risk 3 (§13, disk and thermal cost of video encoding) of
`docs/archive/planning/embedded/apps/19-living-wallpapers.md`.

## Guard

The source scan `specs/138-lw-p01-export-contract/scan-platform-claims.sh` (task T-A19-110, SC-A19-105) runs at every
later phase of A19 over `Packages/ExperiencesCreative/LivingWallpapers`. It refuses:
- the APIs `AVAssetWriter`, `VideoToolbox`, `CVPixelBuffer` and `UIScreen.main.brightness`;
- case-insensitively, the words "live wallpaper", "video" and "set as wallpaper" in the experience's sources and copy.
