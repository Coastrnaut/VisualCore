# Tasks: R02-F02 — public API compatibility and renderer capability probing

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md)

Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-F02 --name <check> -- <command>`. Commit after each
task. Owner-only items: none.

## Phase 1: Setup

- [X] T-R02F02-001 Record the audit and decisions (research.md sections 1–2, done in `/speckit-plan`); baseline: — Verified 2026-11-13: research.md sections 1-2 (audit re-verified by the lead); the starting point is the passing baseline of UA-F07 (api-boundaries-r2: 2184 declarations, 0 undocumented; rendering-ios27/26)
  `check_public_api.py` PASS and the rendering package tests on sim-27.2 (checks `baseline-api`, `baseline-rendering`).

## Phase 2: User Story 1 — An experience can ask what the renderer offers (P1)

Independent test: a fresh host's report holds every value of FR-R02F02-001 and 0 floor findings on both runtimes.

- [ ] T-R02F02-002 [P] [US1] Tests first in `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/RenderCapabilitiesProbeTests.swift`:
  every new value present on a fresh host; `floorFindings()` empty on the simulator and listing a planted low value;
  a value whose query fails is nil (pure helper with an injected reader); a JSON report without the new keys decodes
  with them nil.
- [ ] T-R02F02-003 [US1] Add to `RenderCapabilities.swift` (research R1): optional `maxSamples`, `maxDrawBuffers`,
  `maxColorAttachments`, `maxVertexAttribs`, `maxVertexUniformVectors`, `maxFragmentUniformVectors`,
  `maxTextureImageUnits`, `maxVaryingVectors`, `vertexHighp`, `vertexMediump`, `fragmentHighInt`, `eglVersion`,
  `eglExtensions`, `missingEntryPoints`, `generation`; the queries in `query(display:)` with `vcglGetError` after each
  limit (an error gives nil); `FloorFinding` and `floorFindings()` with the ES 3.0 minima of research R3; `///` on
  every new declaration.
- [ ] T-R02F02-004 [US1] Acceptance: rendering package tests on sim-27.2 and sim-26.5 (checks `rendering-ios27`,
  `rendering-ios26`) (SC-R02F02-001, SC-R02F02-003).

## Phase 3: User Story 2 — The report stays true after the context is rebuilt (P1)

- [ ] T-R02F02-005 [US2] Tests first in `RenderCapabilitiesProbeTests.swift`: after 3 recreations the report's
  `generation` equals the context's; the reload's missing count is in the report.
- [ ] T-R02F02-006 [US2] In `RenderHost.swift`: set `generation` in init; in `recreateContext()` keep the reload
  count, fail with `RenderHostError.unsupported` and the surface-invalid path when it is above 0, otherwise re-query
  `capabilities` (with `generation`) and update `resources.maxTextureSize`.
- [ ] T-R02F02-007 [US2] Acceptance: the rendering package tests on both runtimes again (checks `rendering-ios27-r2`,
  `rendering-ios26-r2`) (SC-R02F02-002).

## Phase 4: User Story 3 — Evidence records the renderer (P2)

- [ ] T-R02F02-008 [P] [US3] Tests first: `Packages/VisualCore/Tests/VisualCoreExperienceTests/RendererRecordTests.swift`
  (round trip with snake-case keys; an evidence JSON without `renderer` decodes); `scripts/tests/test_evidence_renderer.py`
  (`check_evidence.py` accepts a record with and without `environment.renderer`, rejects a non-object `renderer` and
  an identifier-shaped value inside it).
- [ ] T-R02F02-009 [US3] Add `Packages/VisualCore/Sources/VisualCoreExperience/RendererRecord.swift` (data-model.md:
  strings and ints, all optional, unknown keys ignored) and `EvidenceRecord.Environment.renderer` (key `renderer`);
  update `scripts/check_evidence.py`.
- [ ] T-R02F02-010 [US3] Add `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/RendererRecord+Capabilities.swift`
  (`init(_ capabilities:)`, with `floor_findings` from `floorFindings()`), and fill `environment.renderer` in
  `Apps/VisualCore/App/Automation/ScenarioLaunch.swift` from the open session's `renderHost?.capabilities`.
- [ ] T-R02F02-011 [US3] Acceptance: `swift test --package-path Packages/VisualCore` (check `host-visualcore`), script
  tests (check `script-tests`), and one runner scenario whose evidence holds `renderer` (check `verify-renderer`)
  (SC-R02F02-004).

## Phase 5: User Story 4 — The public API stays compatible (P2)

- [ ] T-R02F02-012 [US4] `check_public_api.py --update`: only added lines, 0 undocumented (check `public-api`);
  `check_documented_api.py --sources Apps/VisualCore` (check `documented-api`); package READMEs list the new values
  and the record; `git diff --exit-code <base> -- Packages/VisualCoreRendering/Sources/VisualCoreRendering/EGLDisplayProvider.swift`
  proves the window configuration is unchanged (FR-R02F02-009, check `window-config-unchanged`); the review confirms
  only tracked constant declarations are used (FR-R02F02-010).
- [ ] T-R02F02-013 [US4] Reference regression after the change: `reference-a` and `reference-b` (7 of 7) (SC-R02F02-005).

## Phase 6: Polish

- [ ] T-R02F02-014 Auto-Creator.md section 13 row R02-F02 as built (in place); `validate_autocreator.py` (check `steering`).
- [ ] T-R02F02-015 Evidence `docs`, `legacy-ledger`, `script-tests`; CI of a commit with all changes finished with success.
- [ ] T-R02F02-016 {device} In the device campaign, record the report of D1, D2 and D3 (after ImplementationLock-100).
- [ ] T-R02F02-017 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record R02-F02.

## Dependencies and parallel work

US1 before US2 (same files). US3 (pure record, validator, mapping) runs in parallel with US1/US2: agents may write
`RendererRecord.swift` with its tests and `test_evidence_renderer.py`; the lead owns `RenderCapabilities.swift`,
`RenderHost.swift`, `EvidenceRecord.swift`, `check_evidence.py` and `ScenarioLaunch.swift`. MVP: US1 and US2.

## Analysis

- **Run 1 (2026-11-13)**: E1 MEDIUM (no task proved FR-R02F02-009) fixed in T-R02F02-012; E2 LOW (FR-R02F02-010 by
  review) accepted. 10 of 10 requirements and 5 of 5 criteria covered; no critical or high finding.
