# ADR-0005 — Move the ProjectM-iOS reference pin from 1ad0b99 to d93edd1

**Date:** 2026-11-10 · **Status:** accepted (owner instruction 2026-11-10: "pull the latest projectm-ios commit
and update the submodule")

## Context

`External/projectm-ios` is a pinned, read-only reference (constitution II-a, ADR-0002, contract
`specs/002-architecture-contracts/contracts/tests-adapter-submodule-regression.md` FR-F110). A pin change needs
an owner-approved decision and the full reference regression. The pin was `1ad0b99` (2026-11-10 17:25,
"PresetLibrary performance guard…"). `origin/main` had moved 7 commits to `d93edd1` (feature 002 T239–T250 in
the reference: preset warm-up timing, purchase flow tasks, App Store Connect bookkeeping, D1 automation reports).

## What changed in the reference (1ad0b99..d93edd1)

* 20 files, +4,496/−34. App code (`PresetCoordinator`, `LibraryStore`, preset views, `AutomationRunner`),
  docs, D1 automation JSON reports and specs.
* Renderer: `Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift` (+15 lines) — `prewarm(_:)`
  now starts the background pipeline warm-up after `prewarmDelay` (blend length + 0.5 s) instead of
  immediately; a pending warm-up is cancelled by a new request or deinit. Tests added.
* **Unchanged:** nested pins — ANGLE `Vendor/angle` `29d1823`, projectM `Vendor/projectM` `c88894e`, all five
  preset packs. So `Build/ANGLEFrameworks` and the engine xcframework inputs are unchanged.

## Decision

1. Check out `d93edd1` in the submodule (no reset, no clean, no nested update — nested pins are identical) and
   commit the superproject gitlink.
2. Keep the F00/F01 audit documents as the historical record at `1ad0b99`; this ADR and the evidence below are
   the record for `d93edd1`.
3. VisualCore impact: none expected. VisualCore re-implements the EGL lifecycle (migration boundary 1) and links
   only the unchanged ANGLE frameworks; the changed code (preset warm-up scheduling) is ProjectM-specific and
   stays in the reference (it is not a VisualCore boundary).

## Evidence (ledger stage F07, checks `pin-d93edd1-*`)

Full `scripts/run_reference_baseline.py` sequence at `d93edd1` (engine xcframework, XcodeGen, projectM-iOS /
CaptureLab / RendererLab simulator builds, projectM-iOS generic-iOS build, ANGLERendering tests on iOS 27.2 and
26.5), `scripts/audit_projectm_reference.py`, `scripts/check_reference_clean.py`, the rendering-pipeline
citation check, and the VisualCore regression (host tests, VisualCoreRendering simulator tests on both runtimes,
Showcase build with the dependency audit). Results are recorded in `docs/verification/projectm-baseline.md`
(section "Pin d93edd1").

## Consequences

Future sessions use `d93edd1` as the reference baseline (F07 adapter work included). Any later pin move needs a
new ADR and the same regression.
