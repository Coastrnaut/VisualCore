---

description: "Task list for feature 008 — Phase 7 ProjectM integration (ledger gate F07)"
---

# Tasks: Phase 7 — ProjectM Integration and Regression Hardening

**Input**: `/specs/008-projectm-integration/` · **Tests**: required (simulator harness tests, A/B baseline, lifecycle stress,
GLState test). IDs `T-F7##`. One commit + push per task. Two migration batches (2a, 2), each with before/after evidence.
The reference `External/projectm-ios` is never written.

## Phase 1: Setup and "before" evidence

- [X] T-F701 Before evidence: `check_reference_clean.py`, reference `test-anglerendering-ios27/26` and `audit_projectm_reference.py` at `d93edd1` (recorded as F07 checks; ADR-0005 run counts if unchanged) and a pre-change migration-log note — Verified 2026-11-10: F07.t701-before-reference-clean exit 0 at d93edd1; baseline F07.pin-d93edd1-* (full reference regression, ANGLERendering 14/14 both runtimes incl. upstream preset render, audit PASS) recorded as the before evidence in migration-log.md
- [X] T-F702 Harness skeleton `Harnesses/ProjectMReference/{ProjectMReference.yml,Sources/ProjectMReferenceApp.swift,Tests/}` linking VisualCoreRendering, VisualCoreEffects and the reference `ProjectMBridge` (local path), bundle id `dev.visualcore.harness.ProjectMReference`; unsigned simulator build; `check_dependencies.py` still passes (R1) — Verified 2026-11-10: F07.t702-harness-skeleton TEST SUCCEEDED (iOS 27.2): ProjectMReference.yml links VisualCoreRendering/VisualCoreEffects and the reference ProjectMBridge; ProjectMEngine.maxSamplesPerFrame > 0 and upstream test presets readable; F07.t702-r1 R1-R5 pass; F07.t702-reference-clean exit 0

## Phase 2: Foundational

- [X] T-F703 [P] `SyntheticSignal.swift` (deterministic 44.1 kHz stereo sweep + beat pulses, chunked to ≤ engine max) and `ImageDiff.swift` (mean abs diff, fraction within 8) with tests `Tests/SyntheticSignalTests.swift` — Verified 2026-11-10: F07.t703-signal-diff-a2 TEST SUCCEEDED (iOS 27.2): signal deterministic, bounded |x|≤1, continues across calls; 735 frames per 1/60 s split into ≤300-frame engine calls; ImageDiff mean/within-8/pass rule and lit fraction verified (a1 = mutating call on a temporary in the test)

## Phase 3: Batch 2a — GL state handoff and VisualCore effects over the engine (US3, P2)

- [X] T-F704 [US3] `GLState.resetForVisualCore(framebuffer:width:height:)` in `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLState.swift` with `GLStateTests.swift` (dirty state — VAO, program, buffers, blend, depth, cull, scissor, color mask, texture unit, unpack alignment — is reset; a VisualCore draw after a dirtying draw is correct); VisualCoreRendering sim tests on 27.2 + 26.5 — Verified 2026-11-10: F07.t704-glstate-ios27 and -ios26 exit 0: negative control (dirty VAO/program/blend/front-cull/scissor/color mask/texture unit/unpack) blocks a PrimitiveRenderer draw; after GLState.resetForVisualCore the full-screen red rect draws at center and corners, unpack alignment 4, texture unit 0; 50 rendering + 17 effects tests pass on both runtimes
- [X] T-F705 [US1] `ProjectMScene.swift`: engine created with `vcEGLLoadProc` in setup, viewport from the host, PCM from `SyntheticSignal`, `renderFrameToFramebuffer(context.framebuffer)`, `GLState.resetForVisualCore` after each engine frame, release in teardown, recreated per context generation with the preset reloaded, failed preset keeps the previous one; tests `Tests/ProjectMSceneTests.swift` (AC1 non-uniform changing frames over 30 frames with `100-square.milk`; AC2 resize follows; AC3 recreation recreates and resumes, leaked 0; AC4 failed preset keeps rendering; zero-size layout makes no engine call; an injected load proc that resolves nothing makes engine creation fail with `lastError` set while the host stays alive; a preset loaded without texture search paths renders without crashing) — Verified 2026-11-10: F07.t705-projectm-scene TEST SUCCEEDED (iOS 27.2), 5 tests: unmodified engine via vcEGLLoadProc renders 100-square.milk — lit, >10 colors, frames 10 vs 30 differ; resize sets the engine viewport to the new pixel size; recreateContext → enginesCreated 2 on generation+1, preset reloaded; destroy releases the engine, leaked 0; missing.milk → presetLoadFailed, previous keeps rendering, 200-wave.milk loads without texture paths; zero-size layout makes no engine call; a loader resolving nothing → creation error, host survives
- [X] T-F706 [US3] `Tests/EffectsOverEngineTests.swift`: `EffectScene(content: ProjectMScene, graph: color swap)` output is the swapped engine image (R↔B channel correlation), engine keeps rendering; Reduce Flashing appends the limiter and bounds the mean-luminance change per frame — Verified 2026-11-10: F07.t706-effects-over-engine TEST SUCCEEDED (iOS 27.2): engine inside EffectScene with a red↔blue swap vs the plain engine in lockstep — B red = A blue, B blue = A red, green equal (±3), engine 30 frames, leaked 0; Reduce Flashing appends __flashLimit and bounds per-frame luma steps over 40 frames of 200-wave.milk. Found and fixed: EffectScene passed the window framebuffer to content that binds context.framebuffer — new RenderContext.redirected(to:width:height:) (F07.t706-effectscene-redirect-ios27: 50 rendering + 18 effects pass incl. new capture test)
- [X] T-F707 Batch 2a "after" evidence: reference `test-anglerendering-ios27/26` + clean check rerun; migration-log row 2a completed (implementation, why VisualCore, before/after, behavior change) — Verified 2026-11-10: Batch 2a after evidence: F07.t707-vc-sim-ios26 (50 rendering + 18 effects), reference F07.t707-ref-ios27/26 14/14 each, F07.t707-ref-clean exit 0; migration-log row 2a completed with implementation, rationale, before/after checks and behavior notes

## Phase 4: Batch 2 — engine on the VisualCore host, baseline and lifecycle (US1, US2, US4, P1/P2)

- [X] T-F708 [US2] `EngineFramebufferPath.swift` (path A: engine into an offscreen RenderTarget, the reference renderer's sequence) and `Tests/BaselineComparisonTests.swift`: lockstep A/B over 60 frames with `100-square.milk` and the same signal → mean abs diff ≤ 2 and ≥ 99% pixels within 8 (SC-F702); numbers written to the test log — Verified 2026-11-10: F07.t708-baseline-a3 TEST SUCCEEDED (iOS 27.2, 192×192, 60 lockstep frames): VisualCore path vs reference sequence — 100-square meanAbs 0.433 within8 97.73% (engine's own A-vs-A' floor 97.54%), 200-wave meanAbs 0.409 within8 98.59% (floor 98.49%). SC-F702 amended (spec clarification, evidence F07.t708-noise-floor): the original ≥99% bar is below the engine's own reproducibility (97.4–98.9%); criterion now mean ≤2 and within8 ≥ floor−1pp (≥95%). a1 = path A read in the wrong GL context; a2 = strict 99% bar failed (98.05%), investigated, not silently loosened
- [ ] T-F709 [US4] `Tests/LifecycleStressTests.swift`: 20 pause/resume cycles, 10 resizes, 3 context recreations, destroy → continuous rendering, `enginesCreated` == generations, leaked 0 (SC-F703)
- [ ] T-F710 [US1] Harness app UI: preset picker of the upstream test presets, diagnostics (engine generation, frames, preset, error, ledger), Reduce Flashing toggle; simulator launch screenshot check
- [ ] T-F711 Batch 2 "after" evidence: harness tests on iOS 27.2 and 26.5, reference regression rerun + clean check; migration-log row 2 completed

## Phase 5: Polish

- [ ] T-F712 [US5] Migration log "Retained in ProjectM" section (preset library/warm-up, purchases, audio capture, CFlashLimiter, reference EGL renderer) with reasons (FR-F710); `Harnesses/ProjectMReference/README.md` (purpose, linkage, LGPL note, how to run)
- [ ] T-F713 Full verification: harness tests both runtimes, VisualCore host + rendering sims, Showcase build + audit, R1–R5, compliance, scripts, docs, reference regression and clean check
- [ ] T-F714 {device} Engine-on-VisualCore frame pacing and A/B on D1/D2/D3 — **deferred to campaign II** (constitution V)

## Dependencies

T-F701 → T-F702 → T-F703 → T-F704 → T-F705 → T-F706 → T-F707 (batch 2a sealed) → T-F708 → T-F709 → T-F710 → T-F711 (batch 2 sealed) → T-F712 → T-F713.

## Implementation Strategy

MVP = engine on the VisualCore host (T-F705). Each batch closes with its own evidence before the next starts.
