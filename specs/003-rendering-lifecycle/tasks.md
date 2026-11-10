---

description: "Task list for feature 003 — Phase 2 rendering lifecycle (ledger gate F02)"
---

# Tasks: Phase 2 — Rendering Lifecycle Extraction

**Input**: `/specs/003-rendering-lifecycle/` (plan, spec, research, data-model, contracts/render-host-api.md, quickstart)

**Tests**: The spec requires host tests for the transition table (SC-F203) and simulator pixel tests (SC-F201/SC-F202). They are written before the implementation.

IDs `T-F2##`. Tick only with `— Verified YYYY-MM-DD: <command/result>`. Checks via `desktop_runbook.py run-check --stage F02`.

## Phase 1: Setup

- [ ] T-F201 (FR-F201, FR-F202) Write `Packages/VisualCoreRendering/Sources/CVisualCoreEGL/include/CVisualCoreEGL.h` + `.c`: EGL types/constants/functions from the pinned ANGLE headers (as reference `CANGLE.h`, plus `EGL_VENDOR`, `EGL_VERSION`, `EGL_CONTEXT_LOST`, `EGL_BAD_*`), `vcEGLLoadProc(name, user)` = `eglGetProcAddress`

## Phase 2: Foundational (pure, host-tested)

- [ ] T-F202 [P] (FR-F203, SC-F203) Tests `Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/RenderLifecycleTests.swift`: all 49 state pairs against the contract table, rejection counting, generation increments, history bound
- [ ] T-F203 [P] (FR-F206) Tests `FramePacingTests.swift`: nominal/fair → requested cap; serious → 30; critical → 30 + scale 0.75; low power → 30; requested < 30 clamps to 30
- [ ] T-F204 (FR-F203) Implement `Packages/VisualCore/Sources/VisualCoreDiagnostics/RenderLifecycle.swift`
- [ ] T-F205 (FR-F206) Implement `Packages/VisualCore/Sources/VisualCoreDiagnostics/FramePacing.swift`; add test target `VisualCoreDiagnosticsTests` to `Packages/VisualCore/Package.swift`

## Phase 3: User Story 1 — Minimal scene renders (P1) 🎯 MVP

- [ ] T-F206 [US1] (SC-F201, FR-F212) Simulator tests `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/RenderHostTests.swift`: clear color pixels, gradient left/right dominance, capabilities strings non-empty and version contains "OpenGL ES 3"
- [ ] T-F207 [US1] (FR-F201, FR-F216) `EGLDisplayProvider.swift`: process-wide Metal-platform display, initialized once, never terminated; ES3 RGBA8 window|pbuffer config
- [ ] T-F208 [US1] (FR-F201, FR-F202, FR-F210) `RenderHost.swift`: context + placeholder, `vcglLoad` (fail `unsupported` if any entry missing), capabilities, scene setup, `renderOneFrame`, `readPixels`
- [ ] T-F209 [US1] (FR-F205) `RenderView.swift`: CAMetalLayer BGRA8 opaque view reporting layout/window changes; `layoutSurface()` recreates the window surface only on pixel-size change and notifies `resize`
- [ ] T-F210 [US1] (FR-F212) `SampleScenes.swift`: `ClearColorScene`, `GradientQuadScene` (ES 3.00 program via `vcgl*`)
- [ ] T-F211 [US1] `RenderScene.swift` + `RenderContext`/`FrameInfo`/`RenderHostError` types per contract

## Phase 4: User Story 2 — Resize, background, recreation (P1)

- [ ] T-F212 [US2] (SC-F202) Tests: resize → new pixel size + resize callback; suspend → no frames; 100× `recreateContext()` → generation 101 and correct pixels; zero size → `surfaceInvalid` then recovery; scene setup throwing → error + black frame; injected window-surface creation failures (test hook `failNextSurfaceCreations(n)`) → exactly one `allocation` error after 3 consecutive failures, then recovery (FR-F214)
- [ ] T-F213 [US2] (FR-F207, FR-F208, FR-F214, FR-F215) Implement pause/resume (app + background notifications with `glFinish`), recreation (API + EGL_CONTEXT_LOST detection), surface-failure counting, scene error handling, `replaceScene`
- [ ] T-F214 [US2] (FR-F209) Implement `destroy()` in contract order; test that after destroy the state is `destroyed` and further calls are no-ops

## Phase 5: User Story 3 — Lifecycle observation and pacing (P2)

- [ ] T-F215 [US3] (FR-F203, FR-F204, FR-F206) `FrameScheduler.swift`: CADisplayLink via weak proxy, started/stopped with window membership, `FramePacing` applied on thermal/power notifications, delta clamp 0.1 s; observers receive transitions; debug `dispatchPrecondition(.onQueue(.main))`
- [ ] T-F216 [US3] Tests: observer receives the full transition sequence for create→active→suspend→resume→recreate→destroy

## Phase 6: Polish & regression

- [ ] T-F217 (SC-F206) Generic-iOS build of `VisualCoreRendering-Package`; `check_dependencies.py`; `check_compliance.py`
- [ ] T-F218 (FR-F213, SC-F205) Rerun reference baseline `test-anglerendering-ios27` and `-ios26` + clean check
- [ ] T-F219 (SC-F204) Document < 30-line integration example in `Packages/VisualCoreRendering/README.md` and compile it in a test
- [ ] T-F220 Seal and record ledger gate F02 (all F02 checks incl. `f00rework-*`, `f01rework-*`), push to origin

## Dependencies

Setup → Foundational (tests T-F202/T-F203 before T-F204/T-F205) → US1 (T-F206 tests first) → US2 → US3 → Polish. US2/US3 depend on US1 host.

## Parallel Examples

T-F202 ∥ T-F203; T-F209 ∥ T-F210 (different files).

## Implementation Strategy

MVP = US1 (clear + gradient on both simulators). Implement in bounded groups; run simulator tests after each group.
