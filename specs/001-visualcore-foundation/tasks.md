# Tasks: VisualCore Foundation (feature 001)

Legend: `[P]` parallelizable, `{host}` Mac host, `{sim}` simulator, `{device}` deferred to campaign II.
A task is ticked only with `— Verified YYYY-MM-DD: <command/result>`.

## F01 — Governance and contracts

- [X] T-F001 Constitution v1.0.0 in `.specify/memory/constitution.md` {host} — Verified 2026-11-10: validate_docs.py PASS (no tokens, version 1.0.0), .autonomy/checks/F01.validate-docs.json
- [X] T-F002 ADR-0001..0003, spec, plan, contracts for feature 001 {host} — Verified 2026-11-10: validate_docs.py PASS (ADR Date/Status, FR refs resolve)
- [X] T-F003 `scripts/validate_docs.py` (constitution placeholders, ID uniqueness, task-ID refs) {host} — Verified 2026-11-10: test_scripts.py DocsTests 3/3 OK
- [X] T-F004 `scripts/source_hash_report.py` → `docs/verification/source-hashes.json` {host} — Verified 2026-11-10: source_hash_report.py 33 sources/25 manuals, 0 problems
- [X] T-F005 `scripts/check_compliance.py` (dlopen/dlsym, private frameworks, ReplayKit, ProjectM imports, signing ids) {host} — Verified 2026-11-10: check_compliance.py PASS; test_scripts.py ComplianceTests 6/6 OK
- [X] T-F006 `scripts/test_scripts.py` unit tests for the scripts {host} — Verified 2026-11-10: python3 scripts/test_scripts.py, 10 tests OK

## F02 — Render host (US1)

- [ ] T-F010 `scripts/generate_vcgl.py` → `CVisualCoreGL` table + wrappers from the iOS SDK ES3 header {host}
- [ ] T-F011 `CVisualCoreEGL` shim with pinned ANGLE EGL constants {host}
- [ ] T-F012 `RenderLifecycle` state machine (host-testable model in `VisualCoreDiagnostics`) + tests {host}
- [ ] T-F013 `RenderHost` + `RenderView` (display/config/context/placeholder/window surface, display link, generations, capabilities, readback, forceRecreate) {sim}
- [ ] T-F014 Simulator tests: clear color, gradient quad, resize, suspend/resume, 100 recreations, capabilities on iOS 27.2 + 26.5 {sim}

## F03 — Resources and shaders (US2)

- [ ] T-F020 `ShaderLibrary` include preprocessing with line maps, limits, diagnostics parser + tests {host}
- [ ] T-F021 `ResourceRegistry` (budgets, counters, generations) model + tests {host}
- [ ] T-F022 GL `Texture`, `Buffer`, `Framebuffer`, `ShaderProgram` (uniform table validation, cache) {sim}
- [ ] T-F023 Simulator tests: compile error line mapping, uniform validation, leak-free after recreations {sim}

## F04 — Effects (US2)

- [ ] T-F030 `EffectGraph` validation (cycles, inputs, quota, pass limit) + fixtures {host}
- [ ] T-F031 `FlashLimiterModel` (luminance step bound) + strobe test {host}
- [ ] T-F032 GPU passes copy/colorMatrix/blur/bloom/distort/composite/feedback/flashLimit + target pool {sim}
- [ ] T-F033 Simulator tests: 3-pass graph pixels, failing pass → pass-through, strobe limited {sim}

## F05 — Input, scenes, simulation (US3)

- [ ] T-F040 Math (vec/mat/quat/camera/easing) + reference tests {host}
- [ ] T-F041 FixedStepClock, SeededRandom, Timeline, NaN guard + determinism tests {host}
- [ ] T-F042 InputMapper, PointerTracker, mesh generators, ParticlePool + tests {host}

## F06 — Showcase (US4)

- [ ] T-F050 Root `project.yml` with Showcase target, signing include, Info/privacy {host}
- [ ] T-F051 Showcase scenes (gradient, geometry, distortion, particles, post, diagnostics) {sim}
- [ ] T-F052 Accessibility (labels, Dynamic Type, Reduce Motion/Flashing) + UI smoke test {sim}

## F07 — ProjectM reference adapter (US5)

- [ ] T-F060 Build `ProjectM.xcframework` with the reference's own script (no submodule edits) {host}
- [ ] T-F061 `Harnesses/ProjectMReference` app rendering the engine through RenderHost {sim}
- [ ] T-F062 Regression: reference `ANGLERendering` package tests unchanged on simulator {sim}

## F08 — Second consumer + audio bridge (US5)

- [ ] T-F070 `VisualCoreAudioDSP` (SPSC ring, FFT, bands, RMS, onset) + allocation-free tests {host}
- [ ] T-F071 `VisualCoreAudio` (AVAudioSession mic + in-app player taps; capture labeled unavailable) {sim}
- [ ] T-F072 `Harnesses/SecondConsumer` generative app + teardown/relaunch tests {sim}

## F09 — Stabilization

- [ ] T-F080 `scripts/check_dependencies.py` + `scripts/check_symbols.py` (ProjectM + automation symbols) {host}
- [ ] T-F081 `VisualCoreAutomation` runner (DEBUG || VISUALCORE_AUTOMATION) + Release `nm` scan {sim}
- [ ] T-F082 `scripts/check_privacy_manifest.py`, license notices bundle {host}
- [ ] T-F083 `docs/architecture/visualcore-api.md`, `.github/workflows/ios-ci.yml` (not pushed) {host}
- [ ] T-F084 Full foundation simulator + generic-iOS build sweep {sim}
- [ ] T-F085 Device verification of render host/Showcase {device} — automation ready, deferred to campaign II
