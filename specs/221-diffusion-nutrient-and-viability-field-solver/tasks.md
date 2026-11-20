# Tasks: R02-F21 — Diffusion, nutrient and viability field solver

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F21 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F21 --name <check> -- <command>`. Commit after every task with
its check record (no trailers). No {owner} tasks; one {device} task. Fixture seed 2_021; tests stay short.

## Phase 1: Setup

- [X] T-R02F21-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated — Verified 2026-11-20: 2026-11-20 baseline-host exit 0, baseline-timing exit 0 (.autonomy/migration/checks/R02-F21.baseline-*.json); rendering baseline R02-F20 rendering-27/26 exit 0
  timing run; the rendering baseline is R02-F20's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02F21-002 Create `Packages/VisualCore/Sources/VisualCoreSimulation/NutrientError.swift`, `Packages/VisualCore/Sources/VisualCoreSimulation/NutrientTypes.swift` (NutrientSourceKind, NutrientSource "rate — Verified 2026-11-20: 2026-11-20 host exit 0: NutrientFieldTests 5/5 (1,000 seeded cells: inside 61, outside 801, ramp 138, each equal to the band rule) (.autonomy/migration/checks/R02-F21.host.json)
  finite, 0 < rate ≤ 1,000 units/s", ViabilityBand "finite; low ≤ high; ramp ≥ 0" with membership, NutrientAccount,
  NutrientLedger, NutrientStepReport), `Packages/VisualCore/Sources/VisualCoreSimulation/GrowthNetwork.swift` ("limit 1 … 65,536; perFrame 1 … 1,024; threshold finite,
  0 < t ≤ 1; cost 0 … 2⁴⁰ quanta") and `Packages/VisualCore/Sources/VisualCoreSimulation/NutrientField.swift` (storage "sides 2 … 512; ≤ 262,144 cells; channels
  1 … 4; D finite 0 … 1,000; λ finite 0 … 100; cell and grid total ≤ 2⁴⁰ quanta"; add, remove, addSource "≤ 256",
  setBand, viability, setNetwork, seed, fieldGrid, viabilityGrid; internal storage for the extensions) with
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/NutrientFieldTests.swift` (refusals and codes; add/remove limits and the ledger; viability 1 inside, 0 outside,
  strictly between in a ramp for 1,000 seeded cells; FieldGrid hand-offs); `--name host`

## Phase 3: Stories 1 and 2 — stable diffusion, sources, sinks and decay (P1) 🎯

- [X] T-R02F21-003 [P] [US1] [US2] Create `Packages/VisualCore/Sources/VisualCoreSimulation/NutrientField+Step.swift` (`step(by:)`: frame cut to 0.25 s, n = max(1, — Verified 2026-11-20: 2026-11-20 host-2 exit 0: NutrientDiffusionTests 8/8 (20 fields × 300 frames, 305,557 sub-steps, 0 failures; spread ΔS 7.99988 vs 4·D·t 8.0, error 0.0016 %; settle change 0.0125 %; long frame 256 sub-steps, 2.968 s dropped) (.autonomy/migration/checks/R02-F21.host-2.json)
  ⌈8 · t · Dmax⌉) ≤ 256 sub-steps, dropped time reported; per sub-step sources, sinks, diffusion ⌊r · (a − b)⌋ on
  4-neighbour edges from the sub-step's start, decay ⌊a · (1 − e^(−λh))⌋; ledger and report; growth hook called once per
  frame) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/NutrientDiffusionTests.swift` (20 seeded fields × 300 frames of seeded lengths: every channel
  balanced exactly and no cell negative after every frame; a spot of 2³⁰ quanta on 64 × 64 over 60 frames: peak never rises, spread
  rises every frame and matches 4 · D · elapsed within 1 %; max never rises and min never falls; long frames dropped and reported; sources capped at the limit,
  sinks short; settle within 0.1 % over the last tenth (16 × 16, λ = 1, 600 frames of 1/60 s); an all-zero field;
  time refusals); `--name host-2`

## Phase 4: Story 4 — bounded growth (P2)

- [X] T-R02F21-004 [P] [US3] [US4] Create `Packages/VisualCore/Sources/VisualCoreSimulation/NutrientField+Growth.swift` (growth phase per clarification Q4 and — Verified 2026-11-20: 2026-11-20 host-3 exit 0: GrowthNetworkTests 11/11 (two seeded runs identical over 50 frames; limits, ranking, parents, eaten = cost × grown; breadthFirst routes all 4,005 pairs of a 90-cell network; growth only for t > 0) (.autonomy/migration/checks/R02-F21.host-3.json)
  `networkGraph()`) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/GrowthNetworkTests.swift` (two seeded runs identical; never past limit or per-frame
  limit; every new cell viable, holding at least the cost and next to the network; eaten amounts in the ledger; nowhere
  to go gives zero growth; seed refusals (no network, outside, on the network, at the limit); growth only with t > 0; the network routes through `RouteSearch` between any two of its cells; refusals);
  `--name host-3`

## Phase 5: Story 5 — stored form (P2)

- [X] T-R02F21-005 [P] [US5] Create `Packages/VisualCore/Sources/VisualCoreSimulation/NutrientField+Coding.swift` (Codable JSON schema 1, sorted keys, — Verified 2026-11-20: 2026-11-20 host-4 exit 0: NutrientCodingTests 9/9 (round trip byte for byte, 200 frames continued identically with growth; newer schema; damaged, rule-breaking and unbalanced forms refused) (.autonomy/migration/checks/R02-F21.host-4.json)
  `encoded()`, `decode(_:)` re-validating every rule and the ledger) with `Packages/VisualCore/Tests/VisualCoreSimulationTests/NutrientCodingTests.swift` (round
  trip byte for byte and bit-identical continuation for 200 frames with sources, decay and growth; newer schema;
  damaged, rule-breaking and unbalanced forms refused); `--name host-4`

## Phase 6: Regression, documentation and close

- [X] T-R02F21-006 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences` and — Verified 2026-11-20: 2026-11-20 rendering-27, rendering-26, experiences (sim-27.2) and host-full exit 0
  `--name host-full`
- [X] T-R02F21-007 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-20: 2026-11-20 public-api exit 0 (3,953 declarations, 0 undocumented), documented-api exit 0, 9 new type names unique, docs/architecture/nutrient-fields.md, README section, map F21 as built, render_autocreator + validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/nutrient-fields.md`;
  section in `Packages/VisualCore/README.md`; section 13.4 row R02-F21 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [X] T-R02F21-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-20: 2026-11-20 reference-1 exit 0
- [X] T-R02F21-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-20: 2026-11-20 reference-2 exit 0: 7 of 7 with chunk 1
- [X] T-R02F21-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-20: 2026-11-20 script-tests exit 0, run alone (.autonomy/migration/checks/R02-F21.script-tests.json)
- [X] T-R02F21-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-20: 2026-11-20 converge round 1 converged (nothing appended); sealed 15 passing checks; recorded R02-F21 pass (.autonomy/migration/evidence/R02-F21.json); validators PASS

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F21-012 {device} Measure the frame cost of a 512 × 512 field with four channels and growth on D1–D3 and record
  it in the device campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → {003, 004, 005} in parallel → 006 → … → 011. Agents: A (003), B (004), C (005). Shared files (002, docs)
stay with the lead. MVP: Stories 1 and 2.
