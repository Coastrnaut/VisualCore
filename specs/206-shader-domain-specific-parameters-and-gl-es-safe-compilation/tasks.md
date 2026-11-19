# Tasks: R02-F06 — Shader domain-specific parameters and GL ES safe compilation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F06 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F06 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks; driver behaviour on devices is a {device} item of the campaign (not a task here).

## Phase 1: Setup

- [X] T-R02F06-001 Record the baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F06.{baseline-host,baseline-rendering}.json (exit 0)
  `--name baseline-rendering -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme
  VisualCoreRendering-Package --destination sim-27.2 --action test`

## Phase 2: Foundational (pure, VisualCoreShaderSource)

- [X] T-R02F06-002 [P] Create `Packages/VisualCore/Sources/VisualCoreShaderSource/DefineSet.swift` (name — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F06.host.json (swift test Packages/VisualCore exit 0; 62 ShaderSource tests, 35 new); DefineSetTests 10
  `[A-Za-z_][A-Za-z0-9_]*`, not starting `GL_` or `__`; value without line break, ≤ 256 characters; ≤ 32 defines;
  `DefineError`) and `Packages/VisualCore/Sources/VisualCoreShaderSource/ShaderReasonCode.swift` (the fifteen codes of
  clarification Q4, `ShaderFailureReport` with `feature = "R2-F06"`), with
  `Packages/VisualCore/Tests/VisualCoreShaderSourceTests/DefineSetTests.swift` (also: every `ShaderSourceError`,
  `DefineError` and `VariantError` maps to its reason code; a `ShaderFailureReport` carries `R2-F06` and the caller's
  experience id, seed, tick and tier, analyze C1)
- [X] T-R02F06-003 [P] Modify `Packages/VisualCore/Sources/VisualCoreShaderSource/ShaderLibrary.swift`: include each — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F06.host.json (swift test Packages/VisualCore exit 0; 62 ShaderSource tests, 35 new); IncludeOnceTests 5, PrecisionPolicyTests 8, ShaderLibraryTests unchanged
  file once per expansion; byte-count size guard; `ShaderStageKind`; overload `expand(_:defines: DefineSet, precision:
  PrecisionPolicy?, stage:)`; create `Packages/VisualCore/Sources/VisualCoreShaderSource/PrecisionPolicy.swift`
  (insert `precision highp|mediump float;` after the defines into a fragment shader without a float precision
  statement; findings for `highp` when unsupported); tests in
  `Packages/VisualCore/Tests/VisualCoreShaderSourceTests/IncludeOnceTests.swift` and `PrecisionPolicyTests.swift`;
  existing `ShaderLibraryTests` unchanged and passing

## Phase 3: Story 2 — variants in advance (P1)

- [X] T-R02F06-004 [P] [US2] Create `Packages/VisualCore/Sources/VisualCoreShaderSource/ShaderVariantSet.swift` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F06.host.json (swift test Packages/VisualCore exit 0; 62 ShaderSource tests, 35 new); VariantSetTests 6 (64 accepted, 70 and 128 refused)
  (≤ 6 switches, 1–8 unique values each, ≤ 64 combinations, lexicographic order, key `name=value;…`, `VariantError`)
  with `Packages/VisualCore/Tests/VisualCoreShaderSourceTests/VariantSetTests.swift`

## Phase 4: Story 4 — uniforms and parameters (P1)

- [X] T-R02F06-005 [P] [US4] Create `Packages/VisualCore/Sources/VisualCoreShaderSource/UniformLayout.swift` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F06.host.json (swift test Packages/VisualCore exit 0; 62 ShaderSource tests, 35 new); UniformLayoutTests 6
  (`UniformType` of data-model.md, `UniformDeclaration`, `UniformLayout` with unique names, `UniformLayoutReport`
  `undeclared`/`mistyped`/`unused`, `isValid`, a pure `check(active: [String: UniformType])`) with
  `Packages/VisualCore/Tests/VisualCoreShaderSourceTests/UniformLayoutTests.swift`
- [X] T-R02F06-006 Host checkpoint: `--name host -- swift test --package-path Packages/VisualCore` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F06.host.json (swift test Packages/VisualCore exit 0; 62 ShaderSource tests, 35 new)

## Phase 5: Story 1 — mistakes named before drawing, GL side (P1) 🎯

- [X] T-R02F06-007 [US1] Modify `Packages/VisualCoreRendering/Sources/VisualCoreRendering/ShaderProgram.swift` (log by — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F06.rendering-27.json (exit 0; SafeCompileTests 9, ShaderBindingTests 5; whole scheme 517 tests)
  `GL_INFO_LOG_LENGTH` up to 65,536 bytes; `warnings` from successful compiles; link diagnostics labelled
  `<vertexName>+<fragmentName>`; unparsed line kept; `ShaderError.reasonCode`; reflected `UniformType`;
  `check(_ layout:)`) and `Packages/VisualCoreRendering/Sources/VisualCoreRendering/ResourceRegistry.swift` (overload
  `program(vertex:fragment:defines: DefineSet, precision:library:vertexName:fragmentName:)`; `prewarm(_:vertex:fragment:
  library:precision:) -> PrewarmReport`); create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/ShaderBindings.swift`
  (`PrewarmReport`, `ParameterUniformBinding`, `ParameterBindingError`); `Packages/VisualCoreRendering/Package.swift`
  gains the VisualCoreParameters product; tests in
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SafeCompileTests.swift` (the planted mistakes of
  SC-R02F06-001 on the simulator; six-variant prewarm with six keys and six later cache hits; a failing combination
  reported while others compile; precision inserted and compiled for both policies; `shader.compile` and
  `shader.link` reason codes; a program evicted from a warm set compiles again on the next request and counts a miss,
  analyze C1, C2) and
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ShaderBindingTests.swift` (layout errors and unused;
  parameter values read back with `glGetUniformfv` before and after `recreateContext`; non-finite refused; unused
  parameter reported once)
- [X] T-R02F06-008 [US1] Simulator runs: `--name rendering-27 --` the VisualCoreRendering scheme on sim-27.2 and — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F06.{rendering-27,rendering-26}.json (exit 0 on iOS 27.2 and 26.5)
  `--name rendering-26 --` on sim-26.5 (all existing shader, cache and validation tests pass)

## Phase 6: Regression, documentation and close

- [ ] T-R02F06-009 No Stage One breakage: `--name experiences -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`
- [ ] T-R02F06-010 API baseline and documentation: `python3 scripts/check_public_api.py --update` then `--name
  public-api -- python3 scripts/check_public_api.py`; `///` on every new public symbol; sections in
  `Packages/VisualCore/README.md`, `Packages/VisualCoreRendering/README.md` and `docs/architecture/shaders.md`;
  Auto-Creator.md section 13.4 row R02-F06 "As built"
- [ ] T-R02F06-011 Reference regression chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only
  reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-R02F06-012 Reference regression chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27
  projectm-reference-ios26`)
- [ ] T-R02F06-013 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-R02F06-014 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  R02-F06; README.md and `docs/automatedtesting.md`

## Dependencies

001 → {002, 003, 005}; 002 → 004; {003, 004, 005} → 006 → 007 → 008 → 009 → 010 → 011 → 012 → 013 → 014. 004 uses
002's `DefineSet` by the names of contracts/api.md; 005 depends on nothing new (analyze I1).

## Parallel examples

- **Agent S:** 002, 004. **Agent P:** 003, 005. **Agent G:** 007 after 006. **Lead:** 001, 006, 008–014.
