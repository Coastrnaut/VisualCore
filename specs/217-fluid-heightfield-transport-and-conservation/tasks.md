# Tasks: R02-F17 — Fluid-heightfield transport and conservation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F17 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F17 --name <check> -- <command>`. Commit after every task with
its check record (no trailers). No {owner} and no {device} tasks (frame cost is measured by the consumers in the device
campaign). Fixture seed 2_017; grids ≤ 64 × 64 so tests stay light.

## Phase 1: Setup

- [X] T-R02F17-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`; the rendering — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F17.baseline-host.json and R02-F17.baseline-timing.json (exit 0; mesh bound 2.87 s in the isolated run); rendering baseline = R02-F16.rendering-27.json and rendering-26.json (exit 0)
  baseline is R02-F16's rendering runs (exit 0); timing values in the isolated `VC_TIMING_ASSERTS=1` run

## Phase 2: Foundational

- [X] T-R02F17-002 Create `Packages/VisualCore/Sources/VisualCoreSimulation/HeightfieldError.swift`, `Packages/VisualCore/Sources/VisualCoreSimulation/HeightfieldParameters.swift` (HeightfieldEdges, — Verified 2026-11-19: lead retest 2026-11-19: R02-F17.host.json (exit 0, full suite); HeightfieldStateTests 8 passed (size, channel, parameter, cell and amount refusals incl. the 2⁴⁰ grid total; 600 seeded ledgered edits balanced; surface and field handoff)
  HeightfieldParameters "gravity 0 < g ≤ 100; pipeArea 0 < A ≤ 10; damping 0 … 1; maxSubstep 0 < h ≤ 0.1; maxSubsteps
  1 … 64; rates 0 … 10; all finite", HeightfieldLedger, HeightfieldStepReport) and `Packages/VisualCore/Sources/VisualCoreSimulation/Heightfield.swift` (state "sides
  4 … 1,024, ≤ 262,144 cells; 0 … 4 dye channels; amounts 0 … 2⁴⁰", ledgered add and remove of terrain, water and dye (no sediment edit), totals, `isBalanced`,
  `surface(at:)`, `fieldGrid()`) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/HeightfieldStateTests.swift` (limits and refusals, ledger after edits, field
  handoff values); `--name host`

## Phase 3: Stories 1–2 — conservative, bounded flow (P1) 🎯

- [ ] T-R02F17-003 [US1] [US2] Create `Packages/VisualCore/Sources/VisualCoreSimulation/Heightfield+Step.swift` (research R2–R5: pipe fluxes "0 … 1,000,000", two-phase
  whole-quantum transfers, open edges drained, sub-steps of the stability limit, at most 64, dropped time reported) with
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/HeightfieldFlowTests.swift` (50 seeded terrains × 500 steps: ledger balances and no negative amount after every
  step; 16 × 16 bowl settles within 0.05 in 2,000 sub-steps; water runs downhill; open edges drain and balance; two runs
  identical) and `Packages/VisualCore/Tests/VisualCoreSimulationTests/HeightfieldBoundsTests.swift` (100 seeded extreme cases per SC-R02F17-003; zero time no-op;
  negative and NaN refused; dropped time reported); `--name host-2`

## Phase 4: Story 3 — dye (P2)

- [ ] T-R02F17-004 [US3] Dye carriage in `Packages/VisualCore/Sources/VisualCoreSimulation/Heightfield+Step.swift` (research R4) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/HeightfieldDyeTests.swift`
  (each channel's total exact apart from drain over seeded runs; dye only where water went; a cell sending all its water
  sends all its dye, remainder included; channel refusals); `--name host-3`

## Phase 5: Story 4 — erosion (P2)

- [ ] T-R02F17-005 [US4] Erosion in `Packages/VisualCore/Sources/VisualCoreSimulation/Heightfield+Step.swift` (research R6) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/HeightfieldErosionTests.swift`
  (SC-R02F17-004 16 × 8 slope, 1,000 sub-steps: upper third loses, lower third gains, rock balances exactly; never below the floor; disabled
  erosion leaves terrain unchanged); `--name host-4`

## Phase 6: Story 5 — save and reopen (P2)

- [ ] T-R02F17-006 [US5] Create `Packages/VisualCore/Sources/VisualCoreSimulation/Heightfield+Coding.swift` (schema 1, sorted keys, newer refused, damaged and
  wrong-size arrays malformed) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/HeightfieldCodingTests.swift` (byte-identical round trip; a reopened state
  continues bit-identically for 200 steps; schema 2, truncated JSON and wrong array sizes refused); `--name host-5`

## Phase 7: Regression, documentation and close

- [ ] T-R02F17-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26` and `--name experiences`
- [ ] T-R02F17-008 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/heightfield-transport.md`;
  section in `Packages/VisualCore/README.md`; section 13.4 row R02-F17 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F17-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F17-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F17-011 Script tests (`--name script-tests`)
- [ ] T-R02F17-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → 003 → 004 → 005 → 006 → 007 → … → 012. The sources are one coupled model and stay with the lead; the six test
files are written in parallel by agents against contracts/api.md once 002's types exist, and run by the lead after each
source task. MVP: Stories 1–2.
