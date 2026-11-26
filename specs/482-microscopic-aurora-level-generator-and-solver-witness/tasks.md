# Tasks: R02-G19-02 — Microscopic Aurora: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G19-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_482; tests stay short (< 10 s each; catalog certification in 20 groups of 5 levels, measured locally, never asserted
on CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G1902-001 Baselines after R02-G19-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-26: 2026-11-26: baseline-host, baseline-timing and round02-1, -2, -3c, -3e (with MicroscopicAurora), -3f exit 0 on the committed R02-G19-01 record; rendering baseline is R02-G19-01's rendering runs (exit 0)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two filters of feature 481, chunk 3e with
  MicroscopicAurora); the rendering baseline is R02-G19-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1902-002 Kernel extension and shared types (lead): in — Verified 2026-11-26: 2026-11-26: budgets 1 … 24, optional sites (refusals by name, omitted when absent so feature 481's levels keep their fingerprints), the play's 'not a site' refusal, the puzzle's moves on sites only, generation and witness errors, the 100-entry manifest, plan and difficulty; MicroscopicAuroraSitesTests and all feature 481 suites pass (host exit 0, 45 tests); the budget-13 cases moved to 25
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraLevel.swift` widen `budgets` to "1 … 24" and add
  optional `sites` ("2 … 8 distinct usable cells, row-major"; refusals "sites", "site outside", "sites duplicate", "well
  not on a site"; omitted from the stored form when absent, so every level without sites keeps its fingerprint;
  `allows(_:)`); in `Core/MicroscopicAuroraPlay.swift` refuse a placement the level does not allow with
  `.action("not a site")`; in `Core/MicroscopicAuroraPuzzle.swift` list placements on sites only when sites are listed;
  add `generation(Int)` ("r02-g19.generation") and `witness(String)` ("r02-g19.witness") to
  `Core/MicroscopicAuroraError.swift`; create `Core/MicroscopicAuroraManifest.swift` (the 100 entries "number 1 … 100,
  planned seed, band 1 … 5, budget 8 … 19, emphasis" copied from `python3 scripts/planning_index.py levels --experience
  R02-G19`, with provenance) and `Core/MicroscopicAuroraDifficulty.swift` (placements, stencil, coverage, swarm, sites,
  sets searched, work, nearest miss; `puzzleDifficulty`); move feature 481's out-of-range budget case in
  `CoreTests/MicroscopicAuroraLevelTests.swift` from 13 to 25; create `CoreTests/MicroscopicAuroraSitesTests.swift`
  (sites refused by name, allowed cells, the play's "not a site" refusal, the puzzle's moves on sites only, a level
  without sites encoding byte for byte as before, budgets 13 … 24 accepted); `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

**Independent test**: each catalog level's witness, replayed and played, wins within the budget; no set reachable with
fewer placements wins.

- [X] T-R02G1902-003 [US1] Implement `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSolver.swift` — Verified 2026-11-26: 2026-11-26: MicroscopicAuroraSolver and MicroscopicAuroraSolverTests pass (host-2 exit 0, 9 tests): an independent enumeration agrees with every plan's depth, set counts and nearest miss on levels of every band; agent A found nearestMiss counting the winning depth's misses, fixed (smaller depths only)
  (lead: sets of wells on distinct sites "enumerated by site, then strength, then sense (clockwise first)"; depths 0, 1,
  2 … judged in that order, "the last depth ordered by the loss of the set's prefix judged one depth earlier, ties keeping
  the fixed order"; loss "the stencil cells left unlit plus the cells lit outside the stencil"; the first winning set ends
  the search; the plan's placements "in slot order (slot 0, 1, …)", then `play`; sets counted at each smaller depth and
  the nearest miss; work = sets judged, "bounded at 1,200"; `replayWins` replays the actions and the play through the
  kernel's play) with `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraSolverTests.swift`
  (agent A: hand levels with known minima (one well, two wells); the plan wins and no set with fewer wells does; the
  independent enumeration of every set with fewer placements through the kernel's swim without the loss order on
  seeded levels; the loss order changes only the work, never the depth; the work bound respected; the plan is the first
  in the search order); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

**Independent test**: building the catalog twice gives identical levels and the pinned digest.

- [X] T-R02G1902-004 [US2] Create `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraGenerator.swift` — Verified 2026-11-26: 2026-11-26: MicroscopicAuroraGenerator (committed with T-003, which its solver tests use) and MicroscopicAuroraGeneratorTests pass (host-3 exit 0, 10 tests): manifest shape, determinism, the clarified drawing order re-derived independently, band and kernel ranges, the filters, the neighbour rule, a forced generation refusal
  (lead: band profiles "band 1 (4 … 5, 120, 3, 1, 6 … 24, 600 … 800), 2 (5 … 6, 120 … 140, 4, 1, 10 … 32, 700 … 850),
  3 (6 … 7, 140, 4, 2, 14 … 40, 750 … 900), 4 (7 … 8, 140 … 160, 5, 2, 18 … 50, 800 … 950), 5 (8, 160, 6, 2, 20 … 60,
  850 … 1000)" (swarm, swim length, sites, plan, stencil, coverage); candidates from `SeedDerivation.derive(plannedSeed,
  index: c)` in the drawing order of clarification Q1; enclosure 11; the stencil "the largest four-neighbour group of
  usable cells lit at the threshold, trimmed … to the breadth-first prefix from its densest cell"; the neighbour rule
  (a stencil equal to the previous level's is skipped); at most 64 candidates then `generation(n)`; level ids
  `microscopic-aurora-NNN`; no starting well; tutorial on 1 … 3; difficulty = band; `catalog()` in manifest order;
  catalog digest) with `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraGeneratorTests.swift`
  (agent C: determinism, drawing order, band values and kernel ranges of every candidate, the stencil connected and
  covered by the winning wells, sites distinct and usable, the filters, the neighbour rule, the candidate bound and its
  refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

**Independent test**: band means of the witness length do not fall; the 100 witness files match byte for byte and an
edited file is refused.

- [X] T-R02G1902-005 [P] [US4] Create — Verified 2026-11-26: 2026-11-26: MicroscopicAuroraWitness and MicroscopicAuroraWitnessTests pass (host-4 exit 0, 7 tests): byte-for-byte round trip, digests, replay agreement, damaged, newer and non-replaying witnesses refused
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraWitness.swift` (agent B: schema 1 sorted-key
  JSON; state digests "16 hex characters of the SHA-256 of the wells and the actions spent" after each action; play
  fingerprints after begin (and dismissTutorial) and each action; terminal report (lit stencil cells, coverage, groups,
  smallest coherence and its tick, ticks swum); counterexample (the depth one below, the count of sets at it, the
  nearest miss); difficulty; skipped; decode refuses newer, damaged and non-replaying files) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraWitnessTests.swift`; `--name host-4`
- [X] T-R02G1902-006 [US2] [US3] [US4] Create — Verified 2026-11-26: 2026-11-26: MicroscopicAuroraCatalogTests pass (host-5 exit 0, 8 tests): 100 witness files byte for byte in 20 groups of 5, pinned digest 03c1dc19…, every witness wins within its budget, plan lengths 1, 1, 2, 2, 2 by band with the progression rule, the independent enumeration on two levels per band, one full decode per band
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraCatalogTests.swift` (lead: 100 entries, 20
  per band; every level generated, won by its witness within the budget, and no set with fewer placements wins; the
  independent enumeration without the loss order on the two levels with the fewest sites, then fewest swimmers, in each
  band (ties by level number); neighbours differ; pinned digest; progression rule and band means; witness files byte for
  byte, written only with `MICROSCOPIC_AURORA_WRITE_WITNESSES=1`; 20 groups of 5) and the 100 files
  `docs/games/microscopic-aurora/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1902-007 Docs: `docs/architecture/microscopic-aurora.md` (content pipeline), — Verified 2026-11-26: 2026-11-26: architecture content-pipeline section, round-two README and automatedtesting entry written; round02-host-1, -2, -3c, -3e (with MicroscopicAurora), -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G1902-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-26: 2026-11-26: rendering-27, rendering-26, experiences, host-full exit 0 (app-unit too)
  `--name host-full`
- [X] T-R02G1902-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-26: 2026-11-26: reference-1 exit 0
- [X] T-R02G1902-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-26: 2026-11-26: reference-2 exit 0
- [X] T-R02G1902-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-26: 2026-11-26: script-tests exit 0, run alone
- [ ] T-R02G1902-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (level, play, puzzle, error, manifest, solver,
difficulty, generator, catalog tests, witness files, docs) stay with the lead. MVP: Story 1. Requirement coverage:
FR-001 → 002, 004, 006; FR-002 → 003; FR-003 → 002, 006; FR-004 → 005, 006; FR-005 → 006; FR-006 → 002, 007 … 011;
FR-007 → 004, 006; SC-001 … 005 → 003 … 006; SC-006 → 002, 007 … 011.
