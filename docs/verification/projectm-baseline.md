# ProjectM reference baseline (feature 001, T-F015)

**Date:** 2026-11-10 · **Reference:** `External/projectm-ios` @ `1ad0b99` · **Engine:** projectM `c88894e`
(engine version 4.2.0, `Build/ProjectM.xcframework.json`) · **ANGLE:** `29d1823` (prebuilt, commit-matched)
**Toolchain:** Xcode 27.2 (27B52), iOS SDK 27.2, Swift 6.4.2, XcodeGen 2.46.0, CMake 4.4.5
**Scope:** host + simulator only. No physical device was touched (FR-F009). Simulator results are
functional evidence only, never performance or device evidence (Constitution VI).

## Result: baseline VERIFIED (archived Phase 0 exit gate met)

The unmodified reference builds at the pinned commit, its renderer test suite passes on both
simulator runtimes, and the reference tree is unmodified afterwards.

| Evidence item (spec Clarifications) | Result |
|---|---|
| Engine framework via the reference's own `scripts/build_projectm_xcframework.py` | pass |
| `xcodegen generate` for `project.yml` and `RendererLab.yml` | pass |
| Simulator builds: `projectM-iOS`, `CaptureLab`, `RendererLab` (attempt 2) | pass |
| Generic-iOS unsigned build: `projectM-iOS` | pass |
| `ANGLERendering` tests, iOS 27.2 simulator (iPhone 18 Pro) | **Passed, 13/13** (xcresulttool) |
| `ANGLERendering` tests, iOS 26.5 simulator (iPhone 17 Pro) | **Passed, 13/13** (xcresulttool) |
| Reference clean before and after (incl. nested submodules, gitlink == HEAD) | pass |

### Failed attempt (kept for the audit trail)

`f00rework-build-rendererlab-sim` (attempt 1) exited 65. Building with `-target` plus SYMROOT/OBJROOT
overrides made Xcode's index store try to create `-I…/include/v5/records` ("Read-only file system").
That is a runner invocation error, not a reference defect. Attempt 2 builds the Xcode-autocreated
`RendererLab` scheme like the other apps and succeeds.

## All checks (`desktop_runbook.py run-check`, stage F02 by ledger rule, prefix `f00rework-`)

| Check | Command | Exit | Time | Log | SHA-256 |
|---|---|---|---|---|---|
| `f00rework-build-capturelab-sim` | `python3 scripts/run_reference_baseline.py --step build-capturelab-sim` | 0 | 4.455 s | `.autonomy/logs/F02.f00rework-build-capturelab-sim.log` | `4fba3de34250…` |
| `f00rework-build-projectm-ios-generic` | `python3 scripts/run_reference_baseline.py --step build-projectm-ios-generic` | 0 | 13.189 s | `.autonomy/logs/F02.f00rework-build-projectm-ios-generic.log` | `878b46a07147…` |
| `f00rework-build-projectm-ios-sim` | `python3 scripts/run_reference_baseline.py --step build-projectm-ios-sim` | 0 | 19.853 s | `.autonomy/logs/F02.f00rework-build-projectm-ios-sim.log` | `d3439f2bcc8f…` |
| `f00rework-build-rendererlab-sim-attempt2` | `python3 scripts/run_reference_baseline.py --step build-rendererlab-sim` | 0 | 10.888 s | `.autonomy/logs/F02.f00rework-build-rendererlab-sim-attempt2.log` | `58256ae0ef3a…` |
| `f00rework-build-rendererlab-sim` | `python3 scripts/run_reference_baseline.py --step build-rendererlab-sim` | 65 | 1.654 s | `.autonomy/logs/F02.f00rework-build-rendererlab-sim.log` | `faab211fb0dd…` |
| `f00rework-clean-after-attempt2` | `python3 scripts/check_reference_clean.py` | 0 | 5.429 s | `.autonomy/logs/F02.f00rework-clean-after-attempt2.log` | `008ab5b4d057…` |
| `f00rework-clean-after` | `python3 scripts/check_reference_clean.py` | 0 | 5.587 s | `.autonomy/logs/F02.f00rework-clean-after.log` | `4003d35da612…` |
| `f00rework-clean-before` | `python3 scripts/check_reference_clean.py` | 0 | 5.815 s | `.autonomy/logs/F02.f00rework-clean-before.log` | `ab948a306c2b…` |
| `f00rework-engine-xcframework` | `python3 scripts/run_reference_baseline.py --step engine-xcframework` | 0 | 18.347 s | `.autonomy/logs/F02.f00rework-engine-xcframework.log` | `a7ac1c1ffc0a…` |
| `f00rework-env` | `python3 scripts/verify_environment.py` | 0 | 0.983 s | `.autonomy/logs/F02.f00rework-env.log` | `d1992d301fac…` |
| `f00rework-test-anglerendering-ios26` | `python3 scripts/run_reference_baseline.py --step test-anglerendering-ios26` | 0 | 16.964 s | `.autonomy/logs/F02.f00rework-test-anglerendering-ios26.log` | `a6e1fd11db1c…` |
| `f00rework-test-anglerendering-ios27` | `python3 scripts/run_reference_baseline.py --step test-anglerendering-ios27` | 0 | 12.109 s | `.autonomy/logs/F02.f00rework-test-anglerendering-ios27.log` | `adf9a7aaf022…` |
| `f00rework-xcodegen-main` | `python3 scripts/run_reference_baseline.py --step xcodegen-main` | 0 | 0.267 s | `.autonomy/logs/F02.f00rework-xcodegen-main.log` | `d328fdda716b…` |
| `f00rework-xcodegen-rendererlab` | `python3 scripts/run_reference_baseline.py --step xcodegen-rendererlab` | 0 | 0.239 s | `.autonomy/logs/F02.f00rework-xcodegen-rendererlab.log` | `49e6310e1490…` |

Result bundles: `.autonomy/xcresults/F00rework-anglerendering-ios27.xcresult`,
`.autonomy/xcresults/F00rework-anglerendering-ios26.xcresult` (gitignored, local).

## Reproduce

See `specs/001-baseline-audit/quickstart.md`, or `python3 scripts/run_reference_baseline.py --list`.

## Not covered (follow-ups)

* Other reference package tests (AudioCore, CaptureKit, Diagnostics, CaptureUI, PresetLibrary,
  ProjectMBridge, Rendering) are inventoried but not part of the renderer baseline (research R-F005).
* Device behavior of the reference is historical (VC-016) and is not re-tested here.

## Pin d93edd1 (2026-11-10, ADR-0005)

Owner instruction: pull the latest projectm-ios commit and update the submodule. `1ad0b99` → `d93edd1` (7 reference
commits: feature 002 T239–T250; renderer change limited to the delayed preset warm-up in `ANGLERenderer.prewarm`).
Nested pins unchanged: ANGLE `29d1823`, projectM `c88894e`, all preset packs.

| Check (ledger F07, `pin-d93edd1-*`) | Result |
|---|---|
| engine xcframework (`build_projectm_xcframework.py`) | exit 0 |
| XcodeGen main + RendererLab | exit 0 |
| projectM-iOS, CaptureLab, RendererLab simulator builds; projectM-iOS generic-iOS build | exit 0 |
| ANGLERendering tests iOS 27.2 / 26.5 | 14/14 each (13 before + 1 new warm-up test) |
| `audit_projectm_reference.py` (pins, engine framework commit, ANGLE tree 12.1 GB intact) | PASS, no problems |
| rendering-pipeline citations | 48 citations, 0 unresolved |
| VisualCore: host tests; VisualCoreRendering sim iOS 27.2 / 26.5; Showcase build + dependency audit | all exit 0 |
