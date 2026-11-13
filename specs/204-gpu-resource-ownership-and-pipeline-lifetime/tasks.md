# Tasks: R02-F04 — GPU resource ownership and pipeline lifetime

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md)

Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-F04 --name <check> -- <command>`. Commit after
each task. Tests before code. Owner-only items: none. One {device} task. VisualCore changes, so documentation,
API-baseline and reference-regression tasks apply.

## Phase 1: Setup

- [X] T-R02F04-001 Baseline: VisualCoreRendering scheme on sim-27.2 passes before the change (check `baseline-rendering`); — Verified 2026-11-13: VisualCoreRendering scheme on sim-27.2 passed before the change (baseline-rendering); research.md section 0 re-verified
  research.md §0 re-verified.

## Phase 2: User Story 4 — The existing ownership rules are proven (P2, run first as the regression baseline)

- [X] T-R02F04-002 [US4] Acceptance: the whole VisualCoreRendering scheme (all five test bundles, incl. — Verified 2026-11-13: full VisualCoreRendering scheme (5 bundles) passes on sim-27.2 and sim-26.5 after all changes (rendering-ios27, rendering-ios26); new classes: ProgramCacheTests 0.028/0.020 s, PipelineTests 0.016/0.300 s, DepthTargetTests 0.224/0.201 s, all under 5 s
  ResourceRegistryTests, RenderHostTests, CleanupSweepTests, ProgramCacheTests) passes on sim-27.2 and sim-26.5 after
  all changes (checks `rendering-ios27`, `rendering-ios26`); record the durations of ProgramCacheTests,
  PipelineTests and DepthTargetTests from the logs, each under 5 s (SC-R02F04-004, SC-R02F04-006).

## Phase 3: User Story 1 — A program in use is never deleted by the cache (P1)

- [X] T-R02F04-003 [US1] Tests first in `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ProgramCacheTests.swift`: — Verified 2026-11-13: ProgramCacheTests: amended eviction test (FR-R02F04-014: 64 cached, 1 retired, 1 eviction, 65 live) plus held-evicted-program draws magenta, retired released at recreateContext with 0 leaked, re-request compiles new and both draw; 6 tests pass on 26.5 and 27.2
  amend `testCacheIsBoundedToSixtyFourWithLRUEviction` (comment the reason: FR-R02F04-014) to expect the evicted
  program still alive (`cachedProgramCount` 64, `retiredProgramCount` 1, `evictionCount` 1, live programs 65); new
  test: hold P, create 64 variants, draw a full-screen quad with P and read back the expected colour (not black);
  release P → live count drops by one; new test: retired programs are released at `recreateContext()` with 0
  leaked; new test: requesting P's variant again after eviction compiles a new program and both work.
- [X] T-R02F04-004 [US1] Implement in `Packages/VisualCoreRendering/Sources/VisualCoreRendering/ResourceRegistry.swift`: — Verified 2026-11-13: ResourceRegistry: retired set, evictionCount, retiredProgramCount, release handles retired, contextWillEnd releases retired before abandonAll; internal noteStale() for GLState.apply; tests pass (rendering-ios27/26)
  retired set (`[ObjectIdentifier: ShaderProgram]`), eviction moves without GL delete and counts `evictionCount`,
  `release(_:)` deletes retired programs, `contextWillEnd()` releases retired programs before `abandonAll()`,
  `retiredProgramCount`; `///` docs.
- [X] T-R02F04-005 [US1] Acceptance: ProgramCacheTests pass on sim-27.2 (check `cache-ios27`) (SC-R02F04-001, 005). — Verified 2026-11-13: ProgramCacheTests 6/6 on sim-27.2 within the full scheme run (rendering-ios27) (SC-R02F04-001, 005)

## Phase 4: User Story 2 — One immutable pipeline description (P1)

- [X] T-R02F04-006 [P] [US2] Tests first in `Packages/VisualCore/Tests/VisualCoreShaderSourceTests/RenderStateTests.swift`: — Verified 2026-11-13: RenderStateTests 8 tests (preset fields, ColorMask.all, default equals opaque, equality, hashing, set of presets) pass on host (host-visualcore)
  presets' fields (data-model: "opaque (none, no depth, no cull, all)", "alphaBlended (alpha)", "additive
  (additive, depthWrite false)", "opaque3D (none, depthTest true, depthWrite true, cull back)"); equality and hashing.
- [X] T-R02F04-007 [US2] Write `Packages/VisualCore/Sources/VisualCoreShaderSource/RenderState.swift` per contracts/api.md. — Verified 2026-11-13: VisualCoreShaderSource/RenderState.swift per contracts/api.md with /// docs; tests pass (host-visualcore)
- [X] T-R02F04-008 [US2] Tests first in `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/PipelineTests.swift`: — Verified 2026-11-13: PipelineTests 5 tests: 4 presets plus a custom state after 3 prior states (15 read-backs of blend, depth, cull, mask, program), two pipelines in turn, identity equality, released and stale programs refused and counted; pass on 27.2 and 26.5
  apply each preset after 3 different prior states and read back via `glIsEnabled`/`glGetIntegerv`/`glGetBooleanv`
  (blend enable and factors, depth test, depth mask, cull enable and face, colour mask, current program); `Pipeline`
  equality by program identity; a released program and a program from before `recreateContext()` are refused
  (`apply` false, `staleRejected` +1).
- [X] T-R02F04-009 [US2] Write `Packages/VisualCoreRendering/Sources/VisualCoreRendering/Pipeline.swift` (`Pipeline`) — Verified 2026-11-13: Pipeline.swift (Hashable by program identity and state) and GLState.apply(_:resources:) setting every field; refusal counted via ResourceRegistry.noteStale(); tests pass (rendering-ios27/26)
  and `GLState.apply(_:resources:)` in `GLState.swift`.
- [X] T-R02F04-010 [US2] Acceptance: host RenderStateTests (check `host-visualcore`) and PipelineTests on sim-27.2 — Verified 2026-11-13: host RenderStateTests pass (host-visualcore); PipelineTests pass on sim-27.2 (rendering-ios27) (SC-R02F04-002)
  (check `pipeline-ios27`) (SC-R02F04-002).

## Phase 5: User Story 3 — Offscreen targets with depth (P2)

- [X] T-R02F04-011 [US3] Tests first in `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/DepthTargetTests.swift`: — Verified 2026-11-13: DepthTargetTests 6 tests: nearer colour wins in both orders (control without depth shows last draw), release frees framebuffer and renderbuffer, stale after recreation, invalid sizes, budget smaller than one target leaves nothing allocated, pooled depth targets distinct; pass on 26.5 and 27.2
  a depth target draws two overlapping triangles far-then-near and near-then-far with `RenderState.opaque3D`; the
  nearer colour wins both times; release frees colour and depth (`liveCount[.renderbuffer]` back to 0); context
  recreation rejects the old target; zero or over-limit size throws with nothing allocated; a host with a budget
  smaller than one depth target throws the budget error and leaves no colour, depth or framebuffer allocated; pooled targets with and
  without depth are distinct.
- [X] T-R02F04-012 [US3] Implement depth in `ResourceRegistry.swift` (`makeRenderTarget(..., depth:)`, — Verified 2026-11-13: makeRenderTarget/acquireTarget depth: Bool = false, GL_DEPTH_COMPONENT24 renderbuffer counted as .renderbuffer w*h*4 bytes, cleanup on incomplete framebuffer or budget failure, pool key with depth, RenderTarget.depthRenderbuffer; tests pass
  `acquireTarget(..., depth:)`, pool key with depth, `GL_DEPTH_COMPONENT24` renderbuffer counted as `.renderbuffer`
  width×height×4 bytes, cleanup on incomplete framebuffer) and `GPUObjects.swift` (`RenderTarget.depthRenderbuffer`).
- [X] T-R02F04-013 [US3] Acceptance: DepthTargetTests on sim-27.2 (check `depth-ios27`) (SC-R02F04-003). — Verified 2026-11-13: DepthTargetTests 6/6 on sim-27.2 within the full scheme run (rendering-ios27) (SC-R02F04-003)

## Phase 6: Polish and cross-cutting

- [X] T-R02F04-014 API baseline: `python3 scripts/check_public_api.py --update` then check (check `public-api`); — Verified 2026-11-13: check_public_api --update: 2357 declarations, 0 undocumented, 31 additions (two target factories gain a defaulted depth parameter); check_public_api PASS (public-api); check_documented_api PASS (documented-api)
  `python3 scripts/check_documented_api.py --sources Apps/VisualCore` (check `documented-api`).
- [X] T-R02F04-015 `Packages/VisualCoreRendering/README.md` section "Resource ownership and pipelines (feature 204, R02-F04)". — Verified 2026-11-13: Packages/VisualCoreRendering/README.md section Resource ownership and pipelines (feature 204, R02-F04)
- [X] T-R02F04-016 Host suite `swift test --package-path Packages/VisualCore` (check `host-visualcore`). — Verified 2026-11-13: swift test Packages/VisualCore PASS (host-visualcore)
- [X] T-R02F04-017 ExperiencesCreative on sim-27.2 (check `experiences-ios27`) and A01–A03 verification on iOS 27 — Verified 2026-11-13: ExperiencesCreative on sim-27.2 PASS (experiences-ios27); A01-A03 verification on iOS 27: 0 failures (verify-a01-a03)
  (check `verify-a01-a03`).
- [X] T-R02F04-018 Reference regression chunk 1 (check `reference-1`): `python3 scripts/release_check.py --only — Verified 2026-11-13: reference chunk 1: 3/3 PASS (reference-1)
  reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`.
- [X] T-R02F04-019 Reference regression chunk 2 (check `reference-2`): `python3 scripts/release_check.py --only — Verified 2026-11-13: reference chunk 2: 4/4 PASS, regression 7 of 7 (reference-2)
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`.
- [X] T-R02F04-020 Script tests `python3 scripts/test_scripts.py` (check `script-tests`). — Verified 2026-11-13: python3 scripts/test_scripts.py PASS (script-tests)
- [X] T-R02F04-021 Auto-Creator.md section 13 row R02-F04 as built via `docs/catalog/shared-feature-map.json` and — Verified 2026-11-13: section 13 row R02-F04 rendered; validate_autocreator, validate_docs, migration_baseline verify PASS (docs-autocreator, docs-dossiers, docs-baseline); CI run 43511396405 on the commit with every R02-F04 change completed success (checks, host-tests, simulator-build, app-build)
  `render_autocreator.py`; document validators; CI of a commit with all changes finished with success.
- [ ] T-R02F04-022 {device} In the device campaign: GPU memory used by depth targets and retired programs measured on
  D1, D2, D3 (simulator byte counts are accounting only).
- [X] T-R02F04-023 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record R02-F04. — Verified 2026-11-13: converge round 1 appended T-R02F04-024 (implemented, both runtimes); round 2 appended nothing; T-R02F04-022 {device} stays open

## Dependencies

001 → US1 (003–005) and US2 (006–010) and US3 (011–013); US1 and US3 both edit `ResourceRegistry.swift`, so one
writer does them in order (US1 then US3); US2 is independent → 002 (all bundles on both runtimes) → 014–021 → 023.

## Parallel execution

Agent A: 006–009 (RenderState, Pipeline, GLState.apply, their tests). Agent B: 003–004 then 011–012 (registry,
GPUObjects, ProgramCacheTests, DepthTargetTests). Lead: acceptances, 014–023.

## Implementation strategy

MVP: US1 (the defect). Review checkpoint after each story's acceptance.

## Phase 7: Convergence

Appended by `/speckit-converge` (T-R02F04-023, round 1, 2026-11-13).

- [X] T-R02F04-024 Add a test to `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/DepthTargetTests.swift` that draws the far-then-near and near-then-far triangles into a depth target through `GLState.apply(Pipeline(program:state: .opaque3D), resources:)` and reads back the nearer colour both times, per T-R02F04-011 and US2/US3 integration (partial) — Verified 2026-11-13: DepthTargetTests.testOpaque3DPipelineResolvesOcclusionInADepthTarget: GLState.apply(Pipeline(program, .opaque3D)) returns true and the nearer colour wins in both orders; DepthTargetTests 7/7 and PipelineTests 5/5 on sim-27.2 and sim-26.5 (depth-pipeline-ios27, depth-pipeline-ios26)
