---

description: "Task list for feature 004 — Phase 3 resources and shaders (ledger gate F03)"
---

# Tasks: Phase 3 — Shared GPU Resource and Shader Services

**Input**: `/specs/004-resources-shaders/` · **Tests**: required by the prompt (ownership, cleanup, failures, compilation); written before code.
IDs `T-F3##`. Tick only with `— Verified YYYY-MM-DD: <command/result>`. One commit + push per task.

## Phase 1: Setup

- [X] T-F301 Add test targets `VisualCoreShaderSourceTests` to `Packages/VisualCore/Package.swift` — Verified 2026-11-10: target declared in Package.swift (describe warns "no sources" until T-F302 adds the first test file; verified compiled in T-F302)

## Phase 2: Foundational (pure, host-tested)

- [X] T-F302 [P] Tests `Packages/VisualCore/Tests/VisualCoreShaderSourceTests/SHA256Tests.swift`: NIST vectors ("", "abc", 448-bit, 1 MB 'a') — Verified 2026-11-10: 4 NIST vector tests written (run-check F03.t302-sha256)
- [X] T-F303 [P] Implement `Packages/VisualCore/Sources/VisualCoreShaderSource/SHA256.swift` — Verified 2026-11-10: F03.t302-sha256 exit 0: 4/4 NIST vectors incl. 1M 'a' pass
- [X] T-F304 (FR-F301–F303, FR-F317, SC-F302) Tests `ShaderLibraryTests.swift`: version insertion, defines after version, nested includes with line map (file/line per expanded line), 64 KiB limit, depth 8 limit, cycle, unknown include (file+line), `#version 100` rejected, variant keys differ by defines — Verified 2026-11-10: 11 tests committed first (8518ee7), all pass in F03.t305-shaderlibrary
- [X] T-F305 (FR-F301–F303, FR-F317) Implement `ShaderLibrary.swift`, `LineMap` (in same file), errors `ShaderSourceError` — Verified 2026-11-10: F03.t305-shaderlibrary exit 0: 11 ShaderLibrary tests pass
- [X] T-F306 (FR-F304) Tests `InfoLogParserTests.swift` for `ERROR: 0:N: msg`, warnings, unparseable → raw "unknown"; mapping through `ExpandedShader` — Verified 2026-11-10: 4 tests committed first (c8fadbb), pass in F03.t307-infolog
- [X] T-F307 (FR-F304) Implement `InfoLogParser.swift`, `ShaderDiagnostic`, `ShaderStage` — Verified 2026-11-10: F03.t307-infolog exit 0: 4 parser tests pass (19 total in module)
- [X] T-F308 (FR-F309–F311, SC-F305) Tests `Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/ResourceLedgerTests.swift`: per-kind/total budgets, refusal without change, release to zero, peak, stale, leak accounting, warnings dedupe — Verified 2026-11-10: 7 tests (10127dc + macro fix) pass in F03.t309-ledger-a2
- [X] T-F309 (FR-F309–F311) Implement `Packages/VisualCore/Sources/VisualCoreDiagnostics/ResourceLedger.swift` — Verified 2026-11-10: F03.t309-ledger-a2 exit 0: 7 ResourceLedger tests pass (diagnostics module 18 tests; a1 exit 1 = test macro misuse, kept)

## Phase 3: US1 — Shaders with clear errors (P1) 🎯 MVP

- [X] T-F310 [US1] (SC-F301, FR-F305) Sim tests `ShaderProgramTests.swift`: real ANGLE compile error in an included snippet maps to snippet file/line; failed replacement keeps the old program drawing; captured raw ANGLE log is printed to the test log and matches the InfoLogParser fixture format — Verified 2026-11-10: 5 tests pass in F03.t311-shaderprogram-ios27; real ANGLE log 'ERROR: 0:4: ...' mapped to noise.glsl:2
- [X] T-F311 [US1] Implement `Packages/VisualCoreRendering/Sources/VisualCoreRendering/ShaderProgram.swift` (compile/link via vcgl, uniform table from active uniforms, `ShaderError`) — Verified 2026-11-10: F03.t311-shaderprogram-ios27 exit 0, 21/21 (ShaderProgram + registry.program core; textures/buffers/targets remain T-F313)

## Phase 4: US2 — Textures, buffers, framebuffers (P1)

- [ ] T-F312 [US2] (SC-F303, SC-F305, FR-F310, FR-F313) Sim tests `ResourceRegistryTests.swift`: over-budget refusal, stale handle rejected after recreation, zero live after teardown across 100 recreations, render target render+readback, size validation, trimPools on memory warning
- [ ] T-F313 [US2] Implement `ResourceRegistry.swift` + `GPUObjects.swift` (Texture, GPUBuffer, RenderTarget, GPUHandle, TextureFormat) and attach one registry per `RenderHost` exposed through `RenderContext.resources` (`RenderContext` drops `Sendable` because it is valid only inside main-thread callbacks; equality = generation, size, framebuffer, registry identity); leak accounting on recreation/destroy without GL calls on dead contexts (FR-F316); memory-warning hook

## Phase 5: US3 — Variants, cache, uniforms (P2)

- [ ] T-F314 [US3] (SC-F304, FR-F306, FR-F307) Sim tests: compile count stays 1 for repeated requests; cleared after recreation; LRU bound 64; uniform type mismatch reported once and not applied
- [ ] T-F315 [US3] Implement program cache (SHA-256 key, LRU 64) and uniform validation in `ResourceRegistry`/`ShaderProgram`

## Phase 6: Polish

- [ ] T-F316 (FR-F314, SC-F306) Move `GradientQuadScene` onto `ResourceRegistry.program`; remove `MinimalProgram`; existing pixel tests unchanged and passing
- [ ] T-F317 (FR-F315) Link `docs/rendering/color-space.md` from the package README
- [ ] T-F318 Run host tests, sim tests on 27.2/26.5, generic-iOS build, dependencies, compliance, docs via run-check
- [ ] T-F319 Add migration-log boundary 2a (planned F07) to `docs/architecture/migration-log.md`

## Dependencies

Setup → Foundational (tests before implementations) → US1 → US2 → US3 → Polish. US1 needs T-F305/T-F307; US2 needs T-F309.

## Parallel Examples

T-F302 ∥ T-F304 ∥ T-F306 ∥ T-F308 (separate test files).

## Implementation Strategy

MVP = US1 (diagnostics from real ANGLE errors). Then registry, cache/uniforms, migrate samples.
