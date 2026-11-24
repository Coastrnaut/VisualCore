# Tasks: R02-G16-01 — Starlit Cartouche: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G16-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_451, neighbouring checks seed 2_456; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the star positions, legs and drawn strokes are the CPU reference the renderer of R02-G16-03 will
consume).

## Phase 1: Setup

- [X] T-R02G1601-001 Baselines after X-R02-G15 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24 baseline-host, baseline-timing, baseline-round02-1/2/3 exit 0 (.autonomy/migration/checks/R02-G16-01.baseline-*.json); rendering baseline X-R02-G15 visualcore-rendering
  baseline-round02-1 … 3` (the three round-two filters of feature 446); the rendering baseline is X-R02-G15's
  visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [X] T-R02G1601-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `StarlitCartoucheCore`, — Verified 2026-11-24: 2026-11-24 host exit 0, 4 level tests incl. 200 fixtures winning through the chart (.autonomy/migration/checks/R02-G16-01.host.json); window rule revised (close ≤ 64) so the deadline failure is reachable
  `StarlitCartoucheCoreTests`, product); create `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheError.swift`
  (codes "r02-g16.level, .action, .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheChart.swift` (vectors with squared distance; glyph
  points; a star's position "orbit[b mod length]"; corridors "undirected, travel 1 … 3"; hazards "a corridor and a closed
  beat interval"; `leg(from:at:to:wait:)` refusing "an unknown star, j equal to i, no corridor between i and j, a wait
  outside 0 … 8, and stars out of range at t₀ (squared distance > r²)"; `check` in the order "departure window (t₀ >
  close of i), hazard (a hazard on the corridor whose interval meets [t₀, t₁], the lowest), arrival window (t₁ outside
  j's window), deadline (t₁ > deadline), stroke (corridor not in the symbol)"; the clearance "the fewest beats between a
  hazard interval and a flown leg on its corridor, or nil"; the route report with drawn, missing, stray, mismatch and
  matched), `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheLevel.swift` ("4 … 12 stars", orbits "1 …
  4 positions, coordinates −8 … 8", glyph points "0 … 4, distinct", "range 1 … 12", "at most 24 corridors, no self or
  duplicate corridor", windows "0 ≤ open ≤ close ≤ 64", the start's window "contains 0", "at most 8 hazards" with
  "from ≤ to", start and beacon stars, "deadline 1 … 64", symbol "1 … 12 distinct corridor indices", "budget 1 … 16",
  "difficulty 1 … 5", tutorial, seed, id; stars, corridors and progress named in words (FR-R02G1601-013); JSON schema 1
  with sorted keys and fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheFixtures.swift` (seeded levels with known
  winning legs, built by flying a random route and making its corridors the symbol) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheLevelTests.swift`; `--name host`

## Phase 3: Story 1 — fly a route that draws the cartouche (P1) 🎯

- [X] T-R02G1601-003 [P] [US1] Create `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheChartTests.swift` — Verified 2026-11-24: 2026-11-24 host-2 exit 0, 8 chart tests on 500 seeded levels with an independent beat-by-beat reference (.autonomy/migration/checks/R02-G16-01.host-2.json)
  (agent A: on 500 seeded levels and leg sequences, star positions, range decisions, departure and arrival beats,
  hazard meetings (by listing every beat of [t₀, t₁] against every hazard beat), window and deadline decisions, stroke
  sets, missing, stray, mismatch and clearance equal an independent recomputation; hand cases: a range one unit inside
  and outside, a hazard ending one beat before departure and starting one beat after arrival (clear) and touching each
  end (hazard), arrival exactly on open, close and the deadline, a retraced stroke drawn once); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, budget, undo, redo, replay (P1)

- [X] T-R02G1601-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartouchePlay.swift` — Verified 2026-11-24: 2026-11-24 host-3 exit 0, 15 play tests incl. 500 seeded traces replayed (.autonomy/migration/checks/R02-G16-01.host-3.json); budget payload is the action count
  (agent B: stages "loading, tutorial, playing, paused, won, failed, result"; the ship at the start star at beat 0; `leg`
  validated in the order stage, previous fingerprint, action (the chart's refusals); each spends 1 action; a window,
  hazard, deadline or stroke failure fails the level on that leg with the ship, beat and strokes unchanged; after an
  accepted leg a win (drawn equals the symbol and the ship at the beacon), otherwise a spent budget fails
  `budget(actions spent)`; the route report after every action; records with previous and next fingerprints; full undo
  and redo (from failed back to playing before the failing leg, its action refunded, recorded; won is final); replay)
  with `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartouchePlayTests.swift` (known legs win on the
  exact leg; each failure named; budget failure on the exact action with one action either side; a leg on the last
  action wins; 500 seeded traces replay; undo restores exact fingerprints; every refusal reason reachable);
  `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G1601-005 [P] [US4] Create `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheRules.swift` — Verified 2026-11-24: 2026-11-24 host-4 exit 0, 5 rules tests incl. 200 walks agreeing with the play (.autonomy/migration/checks/R02-G16-01.host-4.json)
  (agent C: `PuzzleRules`: State = position (star, beat, drawn, actions spent, outcome), Move = StarlitCartoucheAction;
  legal moves while playing "every corridor from the star, waits 0 … 8, flyable ones only") with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheRulesTests.swift` (agreement with the play on
  200 walks); `--name host-4`
- [X] T-R02G1601-006 [P] Create `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheInvariantTests.swift` — Verified 2026-11-24: 2026-11-24 host-5 exit 0, 9 invariant tests each with a seeded neighbouring check, seed 2_456 (.autonomy/migration/checks/R02-G16-01.host-5.json)
  (agent D: `testStarlitCartoucheTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_456); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1601-007 Docs: `docs/architecture/starlit-cartouche.md` (new: rules), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-24: 2026-11-24 round02-host-1/2/3 exit 0 (59 s, 45 s, 340 s; .autonomy/migration/checks/R02-G16-01.round02-host-*.json)
  `docs/automatedtesting.md`; `--name round02-host-1 … 3`
- [X] T-R02G1601-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24 rendering-27, rendering-26, experiences, host-full exit 0 (app-unit too; .autonomy/migration/checks/R02-G16-01.*.json)
  `--name host-full`
- [X] T-R02G1601-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24 reference-1 exit 0 (.autonomy/migration/checks/R02-G16-01.reference-1.json)
- [ ] T-R02G1601-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1601-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1601-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, chart, level, fixtures, docs) stay with
the lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement coverage: FR-001,
009, 013 → 002; FR-002, 003, 014 → 002, 003; FR-004 … 008, 011 → 004; FR-010 → 005; FR-012 → 006; SC-001 … 005 →
002 … 006; SC-006 → 007 … 011.
