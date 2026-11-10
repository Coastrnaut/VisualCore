---

description: "Task list for feature 003 — Phase 2 rendering lifecycle (ledger gate F02)"
---

# Tasks: Phase 2 — Rendering Lifecycle Extraction

**Input**: `/specs/003-rendering-lifecycle/` (plan, spec, research, data-model, contracts/render-host-api.md, quickstart)

**Tests**: The spec requires host tests for the transition table (SC-F203) and simulator pixel tests (SC-F201/SC-F202). They are written before the implementation.

IDs `T-F2##`. Tick only with `— Verified YYYY-MM-DD: <command/result>`. Checks via `desktop_runbook.py run-check --stage F02`.

## Phase 1: Setup

- [X] T-F201 (FR-F201, FR-F202) Write `Packages/VisualCoreRendering/Sources/CVisualCoreEGL/include/CVisualCoreEGL.h` + `.c`: EGL types/constants/functions from the pinned ANGLE headers (as reference `CANGLE.h`, plus `EGL_VENDOR`, `EGL_VERSION`, `EGL_CONTEXT_LOST`, `EGL_BAD_*`), `vcEGLLoadProc(name, user)` = `eglGetProcAddress` — Verified 2026-11-10: CVisualCoreEGL.h/.c compile in generic-iOS build (F02.f02-rendering-generic-ios BUILD SUCCEEDED)

## Phase 2: Foundational (pure, host-tested)

- [X] T-F202 [P] (FR-F203, SC-F203) Tests `Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/RenderLifecycleTests.swift`: all 49 state pairs against the contract table, rejection counting, generation increments, history bound — Verified 2026-11-10: swift test VisualCore: RenderLifecycleTests incl. 49-pair parameterized table pass (F02.f02-pure-swift-test)
- [X] T-F203 [P] (FR-F206) Tests `FramePacingTests.swift`: nominal/fair → requested cap; serious → 30; critical → 30 + scale 0.75; low power → 30; requested < 30 clamps to 30 — Verified 2026-11-10: FramePacingTests 6 tests pass (F02.f02-pure-swift-test)
- [X] T-F204 (FR-F203) Implement `Packages/VisualCore/Sources/VisualCoreDiagnostics/RenderLifecycle.swift` — Verified 2026-11-10: RenderLifecycle.swift; table/generation/history tests pass
- [X] T-F205 (FR-F206) Implement `Packages/VisualCore/Sources/VisualCoreDiagnostics/FramePacing.swift`; add test target `VisualCoreDiagnosticsTests` to `Packages/VisualCore/Package.swift` — Verified 2026-11-10: FramePacing.swift + VisualCoreDiagnosticsTests target; tests pass

## Phase 3: User Story 1 — Minimal scene renders (P1) 🎯 MVP

- [X] T-F206 [US1] (SC-F201, FR-F212) Simulator tests `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/RenderHostTests.swift`: clear color pixels, gradient left/right dominance, capabilities strings non-empty and version contains "OpenGL ES 3" — Verified 2026-11-10: F02.f02-rendering-tests-ios27-a4 / -ios26-a4 exit 0, 15/15 tests (clear ±2, gradient, capabilities "OpenGL ES 3"/ANGLE, display scale)
- [X] T-F207 [US1] (FR-F201, FR-F216) `EGLDisplayProvider.swift`: process-wide Metal-platform display, initialized once, never terminated; ES3 RGBA8 window|pbuffer config — Verified 2026-11-10: EGLDisplayProvider; testTwoHostsRenderIndependently passes on both runtimes
- [X] T-F208 [US1] (FR-F201, FR-F202, FR-F210) `RenderHost.swift`: context + placeholder, `vcglLoad` (fail `unsupported` if any entry missing), capabilities, scene setup, `renderOneFrame`, `readPixels` — Verified 2026-11-10: RenderHost; F02.f02-rendering-tests-ios27-a4 / -ios26-a4 exit 0, 15/15 tests
- [X] T-F209 [US1] (FR-F205) `RenderView.swift`: CAMetalLayer BGRA8 opaque view reporting layout/window changes; `layoutSurface()` recreates the window surface only on pixel-size change and notifies `resize` — Verified 2026-11-10: RenderView; testResizeRecreatesTheSurfaceAndNotifiesTheScene passes
- [X] T-F210 [US1] (FR-F212) `SampleScenes.swift`: `ClearColorScene`, `GradientQuadScene` (ES 3.00 program via `vcgl*`) — Verified 2026-11-10: SampleScenes ClearColor/GradientQuad pixel tests pass
- [X] T-F211 [US1] `RenderScene.swift` + `RenderContext`/`FrameInfo`/`RenderHostError` types per contract — Verified 2026-11-10: RenderScene/RenderContext/FrameInfo/RenderHostError compile and are used by tests

## Phase 4: User Story 2 — Resize, background, recreation (P1)

- [X] T-F212 [US2] (SC-F202) Tests: resize → new pixel size + resize callback; suspend → no frames; 100× `recreateContext()` → generation 101 and correct pixels; zero size → `surfaceInvalid` then recovery; scene setup throwing → error + black frame; injected window-surface creation failures (test hook `failNextSurfaceCreations(n)`) → exactly one `allocation` error after 3 consecutive failures, then recovery (FR-F214) — Verified 2026-11-10: resize/suspend/background/100 recreations (generation 101)/zero size/3 surface failures/scene error tests pass (F02.f02-rendering-tests-ios27-a4 / -ios26-a4 exit 0, 15/15 tests; a2 zero-size test-setup failure kept)
- [X] T-F213 [US2] (FR-F207, FR-F208, FR-F214, FR-F215) Implement pause/resume (app + background notifications with `glFinish`), recreation (API + EGL_CONTEXT_LOST detection), surface-failure counting, scene error handling, `replaceScene` — Verified 2026-11-10: pause/resume, background glFinish, recreation, surface-failure counting, scene errors, replaceScene covered by passing tests
- [X] T-F214 [US2] (FR-F209) Implement `destroy()` in contract order; test that after destroy the state is `destroyed` and further calls are no-ops — Verified 2026-11-10: testDestroyTearsDownAndLaterCallsAreNoOps passes

## Phase 5: User Story 3 — Lifecycle observation and pacing (P2)

- [X] T-F215 [US3] (FR-F203, FR-F204, FR-F206) `FrameScheduler.swift`: CADisplayLink via weak proxy, started/stopped with window membership, `FramePacing` applied on thermal/power notifications, delta clamp 0.1 s; observers receive transitions; debug `dispatchPrecondition(.onQueue(.main))` — Verified 2026-11-10: FrameScheduler (CADisplayLink proxy, pacing); testObserverSeesTheFullLifecycle passes
- [X] T-F216 [US3] Tests: observer receives the full transition sequence for create→active→suspend→resume→recreate→destroy — Verified 2026-11-10: testObserverSeesTheFullLifecycle passes on both runtimes

## Phase 6: Polish & regression

- [X] T-F217 (SC-F206) Generic-iOS build of `VisualCoreRendering-Package`; `check_dependencies.py`; `check_compliance.py` — Verified 2026-11-10: F02.f02-rendering-generic-ios BUILD SUCCEEDED; f02-dependencies, f02-compliance exit 0
- [X] T-F218 (FR-F213, SC-F205) Rerun reference baseline `test-anglerendering-ios27` and `-ios26` + clean check — Verified 2026-11-10: F02.f02-ref-anglerendering-ios27-a2 / -ios26-a2: reference 13/13 TEST SUCCEEDED; clean before/after (a1 exit 64 = result-bundle name reuse, kept)
- [X] T-F219 (SC-F204) Document < 30-line integration example in `Packages/VisualCoreRendering/README.md` and compile it in a test — Verified 2026-11-10: README example compiled and rendered by ReadmeExampleTests (15th test) on both runtimes
- [ ] T-F220 Seal and record ledger gate F02 (all F02 checks incl. `f00rework-*`, `f01rework-*`), push to origin

## Dependencies

Setup → Foundational (tests T-F202/T-F203 before T-F204/T-F205) → US1 (T-F206 tests first) → US2 → US3 → Polish. US2/US3 depend on US1 host.

## Parallel Examples

T-F202 ∥ T-F203; T-F209 ∥ T-F210 (different files).

## Implementation Strategy

MVP = US1 (clear + gradient on both simulators). Implement in bounded groups; run simulator tests after each group.
