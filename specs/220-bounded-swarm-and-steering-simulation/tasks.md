# Tasks: R02-F20 — Bounded swarm and steering simulation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F20 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F20 --name <check> -- <command>`. Commit after every task with
its check record (no trailers). No {owner} tasks; one {device} task. Fixture seed 2_020; tests stay short.

## Phase 1: Setup

- [ ] T-R02F20-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated
  timing run; the rendering baseline is R02-F19's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02F20-002 Create `Packages/VisualCore/Sources/VisualCoreSimulation/SwarmError.swift` and `Packages/VisualCore/Sources/VisualCoreSimulation/MagneticField.swift` (MagneticPole "finite; abs(s) ≤ 1,000;
  ε ≥ 1e-6", MagneticField "finite; abs(B) ≤ 100; ≤ 64 poles", poleForce, poleForceBound, exact turned(_:charge:step:))
  with `Packages/VisualCore/Tests/VisualCoreSimulationTests/MagneticFieldTests.swift` (refusals and codes; 1,000 seeded positions including the pole within the bound;
  an attracting pole pulls inward; turning keeps length within 1e-12); `--name host`

## Phase 3: Story 1 — neighbourhood grid (P1) 🎯

- [ ] T-R02F20-003 [P] [US1] Create `Packages/VisualCore/Sources/VisualCoreSimulation/NeighbourGrid.swift` (clarification Q2, ≤ 65,536 agents) with
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/NeighbourGridTests.swift` (50 seeded swarms of 10 … 1,000 agents and one of 2,000: every list equals
  `NeighbourSearch`, order included, for several radii and limits; non-finite agents and agents at ±1e300; radius larger
  than the cell and a radius of 1e300; refusals); `--name host-2`

## Phase 4: Story 4 — density raster (P2)

- [ ] T-R02F20-004 [P] [US4] Create `Packages/VisualCore/Sources/VisualCoreSimulation/DensityRaster.swift` ("width, height 1 … 1,024; ≤ 1,048,576 cells; bounds
  valid") with `Packages/VisualCore/Tests/VisualCoreSimulationTests/DensityRasterTests.swift` (50 seeded swarms: total equals the in-area count within 1e-9 relative; a
  cell-centre agent lands in one cell; edge folding; non-finite and outside agents excluded; field grid handoff;
  refusals); `--name host-3`

## Phase 5: Stories 2, 3 and 5 — the swarm (P1, P2)

- [ ] T-R02F20-005 [US2] [US3] [US5] Create `Packages/VisualCore/Sources/VisualCoreSimulation/Swarm.swift` (SwarmEdges; Swarm "≤ 65,536 agents; charges count = agents
  count, each finite with abs(q) ≤ 100; bounds valid; agents finite; neighbourRadius finite > 0, neighbourLimit ≥ 1, others finite ≥ 0; speedLimit finite > 0; JSON schema 1;
  decode re-validates"; step per clarification Q3)
  with `Packages/VisualCore/Tests/VisualCoreSimulationTests/SwarmTests.swift` (20 seeded swarms of 20 … 200 agents × 500 steps twice bit-identical, every agent inside its bounds with speed
  ≤ limit after every step, walled and wrapping; a lone charge in a uniform field keeps its speed within 1e-9 over 1,000
  steps and closes its orbit within 1e-9 of the radius; an empty swarm steps; non-finite agents and invalid parameters refused; round
  trip byte for byte and bit-identical continuation for 200 steps; newer, damaged and rule-breaking forms refused; step and size
  refusals); `--name host-4`

## Phase 6: Regression, documentation and close

- [ ] T-R02F20-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26` and `--name experiences`
- [ ] T-R02F20-007 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/swarms.md`; section in
  `Packages/VisualCore/README.md`; section 13.4 row R02-F20 "As built" in `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`
- [ ] T-R02F20-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F20-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F20-010 Script tests (`--name script-tests`)
- [ ] T-R02F20-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F20-012 {device} Measure the frame cost of a large swarm with density on D1–D3 and record it in the device
  campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → {003, 004} in parallel → 005 (needs 003) → 006 → … → 011. Agents: A (003), B (004), C (005 after 003).
Shared files (002, docs) stay with the lead. MVP: Stories 1 and 2.
