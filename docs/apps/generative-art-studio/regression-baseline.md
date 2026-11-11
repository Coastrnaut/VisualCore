# Generative Art Studio — ProjectM regression baseline (A01-P00; app regression updated A01-P05)

**Phase-start commit:** `8172b76` ("Seal F09…"), the last commit before feature 011. FR-A01-007 checks
`git diff --stat 8172b76..HEAD -- Packages External`, which must stay empty for Phase 00.

**Reference pin:** `External/projectm-ios` at `d93edd1` (ADR-0005); nested ANGLE `29d1823`, projectM `c88894e`.

## Results (T-A01-006, 2026-11-10)

Command, run under ledger check `A01-P00/t006-reference-regression`:

```bash
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim \
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 reference-clean \
  projectm-reference-ios27 projectm-reference-ios26
```

| Step | Result | Detail |
|---|---|---|
| reference-engine-xcframework | pass | projectM engine xcframework built from the pinned reference |
| reference-build-projectm-ios-sim | pass | projectM-iOS app, generic iOS Simulator |
| reference-test-anglerendering-ios27 | pass | ANGLERendering 14/14 tests, iOS 27.2 simulator |
| reference-test-anglerendering-ios26 | pass | ANGLERendering 14/14 tests, iOS 26.5 simulator |
| reference-clean | pass | reference working tree and pins unchanged (`d93edd1`) |
| projectm-reference-ios27 | pass | ProjectMReference harness 17/17 tests, iOS 27.2 |
| projectm-reference-ios26 | pass | ProjectMReference harness 17/17 tests, iOS 26.5 |

**7/7 steps pass.** These are simulator results, not device evidence. Any later A01 phase that changes VisualCore
reruns this set and compares against this table (constitution II-a).

## Phase 05 regression, accessibility audit and lifecycle fixture (A01-P05, 2026-11-11)

**Reference regression after the A01-P05 VisualCore change** (`AccessibilityPreferences`,
`SystemAccessibilityObserver`, `EffectScene.bypassEffects`): ledger checks `A01-P05/t503-reference-a` (3/3) and
`t503-reference-b` (4/4), **7/7 pass**, the same table as above.

**App suites** (Phases 01–05, iOS 27.2 and 26.5 simulators): 36 unit tests and 13 UI tests per runtime. Each run is
confirmed by `scripts/check_test_enumeration.py`, because a 26.5 run that follows a 27.2 run in the same DerivedData
twice skipped newly added test classes without reporting a skip. Such a run is never counted as evidence.

**Lifecycle fixture** (`LifecycleRegressionTests`, the manual's Phase 05 gate). For every family, background →
foreground and context recreation restore the same image at the same time (mean difference 0.0). After recovery:
stale-handle uses 0, leaks 0, and live resources are recreated one for one. 20 background cycles plus 3 recreations
cause no growth. An export after recovery is identical to one before, and the Reduce-Flashing limiter rebuilds.

**Accessibility audit** (`AccessibilityAuditUITests`): gallery, settings, library, scene, controls and export.
- At the default size, every audit type except Dynamic Type and clipping (which are only predictions there).
- At `UICTContentSizeCategoryAccessibilityXXXL`, every type.

Every finding on the app's own views was fixed. The documented exclusions (spec Clarifications) that remain on both
runtimes are all navigation-bar chrome:

| Screen | Element | Finding | Why it is documented, not fixed |
|---|---|---|---|
| settings, export | system "Done" bar button | contrast; Dynamic Type partially unsupported | iOS draws bar buttons in its own style and sizes bars itself; the Large Content Viewer covers them |
| scene | inline title `gas.scene.title` (one line, scales down, Large Content Viewer) | Dynamic Type partially unsupported (XXXL) | fixed-height navigation bar |

No canvas-artwork or element-less exclusions remain after the fixes. Human VoiceOver review on the devices is
campaign II.
