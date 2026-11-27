# Tasks: R02-G21-01 — Binary Gardens: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_501, neighbouring checks seed 2_506; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no
GLSL in this feature (the positions, fluxes with each star's share, bands, runs, windows and integrals are the CPU
reference the renderer of R02-G21-03 will consume). Agents compile but run no tests while the lead's baselines or chain
run. Every `host` … `host-5` check runs `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`.

## Phase 1: Setup

- [X] T-R02G2101-001 Baselines after X-R02-G20 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit=0 (.autonomy/migration/checks/R02-G21-01.baseline-*.json)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two chunks of feature 457 with the five filters as at
  R02-G20-10, without `BinaryGardens`, on the committed tree before the targets exist); the rendering baseline is
  X-R02-G20's visualcore-rendering run

## Phase 2: Foundational

- [X] T-R02G2101-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `BinaryGardensCore` depending on — Verified 2026-11-27: host exit=0, 41 tests in 5 suites incl. LevelTests and SkyTests (.autonomy/migration/checks/R02-G21-01.host.json); targets BinaryGardensCore and tests added; CI half b filter includes BinaryGardens
  VisualCoreSimulation and VisualCoreMath, path `BinaryGardens/Core`; `BinaryGardensCoreTests`, path
  `BinaryGardens/CoreTests`, depending on BinaryGardensCore, VisualCoreSimulation and VisualCoreMath; product) and
  `.github/workflows/ci.yml` (job `round02-host-tests`, matrix `group: b`: `|BinaryGardens` appended after
  `MushroomWeather` in its `--filter`; half a unchanged; no new step or job; research R12); create
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensError.swift` (codes "r02-g21.level, .action, .budget,
  .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSky.swift` (the 48-tick cycle: the cosine table as 48
  literal integers at scale 1024, `sine` "cosine[(step + 36) mod 48]", `phase` "non-negative (start + speed·tick) mod
  48"; positions at scale 2^20, world "(a·C[ψ]·1024, a·S[ψ]·1024, 0)", star "(ρ·C[θ]·1024, ρ·S[θ]·C[τ], ρ·S[θ]·S[τ])";
  squared distances at scale 2^40; the milliflux "share = ⌊1000·L·2^40 / max(D, r_min²·2^40)⌋ ≤ 64 000", "flux =
  share₁ + share₂"; the bands "F < λ_lo; λ_lo ≤ F < c_lo; c_lo ≤ F ≤ c_hi; c_hi < F ≤ λ_hi; F > λ_hi"; the integral "I
  = Σ flux over ticks 1 … 48"; the longest lethal run "cyclic, capped at 48"; the longest cyclic comfortable window with
  its start tick (the smallest start among equal longest runs, tick 1 when all 48 ticks are comfortable); the minimum
  squared separation over ticks 0 … 47 and the earliest tick at which it occurs; `keepsSeparation`; the judge: the
  lethal walk over ticks 1 … 48 + E ("tick is the walk tick 1 … 48 + E", `frozen` or `scorched` at the first tick a
  world's lethal run exceeds E, a run across the cycle boundary counted whole), then per world in ascending order
  `unstable` before `wilted` or `bleached`, otherwise won; the report "exact; computed after every action; never decides
  by itself (the play ends only on `run`)"),
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensLevel.swift` (stars "indices in range; exactly two per
  level"; worlds "radius a 1 … 60, phase ψ 0 … 47, speed ν −4 … 4", "window W 1 … 48", "0 ≤ λ_lo < c_lo ≤ c_hi < λ_hi ≤
  200 000 milliflux; 0 ≤ B_lo ≤ B_hi ≤ 9 600 000; 1 … 5 per level"; "difficulty 1 … 5, ringRadii (2 … 8, strictly
  increasing, each 1 … 40), starSpeed ω 1 … 3, luminosityLevels (1 … 4, strictly increasing, each 1 … 64)", "maxTilt
  T_max 0 … 6, startTilt 0 … T_max, minimumSeparation σ 0 … 16, clampRadius r_min 1 … 8", "lethalTolerance E 0 … 12,
  budget 1 … 24", tutorial, seed, id; refused per FR-R02G2101-001 ("refused `r02-g21.level` when any value is out of
  range or out of order, nothing is adjustable (all six star flags false and T_max = 0), a star's luminosity is marked adjustable
  while there is only one luminosity level, the starting stars break the
  separation at a tick of 0 … 47, or the starting arrangement already wins"); the arrangement "indices in range; 0 ≤ τ ≤
  T_max; keeps the separation at every tick 0 … 47"; stars, rings, worlds, bands, measures and progress named in words
  (FR-R02G2101-013); JSON schema 1 with sorted keys and fingerprint ("SHA-256 of the canonical text of every other field
  (schema included, fingerprint excluded)"); decode re-checks in order ("broken JSON → `r02-g21.malformed`; `schema` > 1 →
  `r02-g21.newer-schema`; a schema below 1 or a missing field → `r02-g21.malformed`; any value that the initializer
  refuses → `r02-g21.level`; a fingerprint that does not match the canonical text → `r02-g21.malformed`")) and
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensFixtures.swift` (seeded levels with known winning
  arrangements, `SeededRandom(seed: 2_501)`, built by choosing rings, luminosities, a tilt range, worlds and an
  arrangement that keeps the separation, running it, taking each world's four flux bounds around its tick fluxes so its
  comfortable window reaches W and no lethal run exceeds E, and its bloom band around its integral, then choosing a
  starting arrangement that keeps the separation and does not win) with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensLevelTests.swift` (ranges, every refusal, stored
  form, the cosine table equal to the nearest integer to 1024·cos(7.5°·k) and its symmetry rules, every body back at
  its start after 48 ticks, fixtures, hand cases, words); `--name host`

## Phase 3: Story 1 — balance the twin stars so every garden world stays in its light (P1) 🎯

- [X] T-R02G2101-003 [P] [US1] Create — Verified 2026-11-27: host-2 exit=0, BinaryGardensSkyTests with the independent reference over 500 seeded runs (file committed with T-002) (.autonomy/migration/checks/R02-G21-01.host-2.json)
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSkyTests.swift` (agent A: an independent
  reimplementation of the cosine table from its symmetry rules, the positions, the milliflux law, the bands, the lethal
  walk, the cyclic window, the integrals and the judge, written from the spec's clarifications only, compared with the
  kernel on 500 seeded runs: every position, star share, flux, band, lethal run, window, integral, minimum separation
  and outcome equal; hand cases: a flux one milliflux either side of each of the four bounds, a distance one unit either
  side of the clamp radius, a lethal run one tick either side of the tolerance (also across the cycle boundary, and
  tolerance 0), a mixed lethal-low-then-high run, a window one tick short of the requirement and the whole cycle comfortable, an integral one milliflux
  either side of each bloom bound, a separation one unit either side of the minimum, the judge order frozen/scorched →
  unstable → wilted/bleached); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, undo, redo, replay (P1)

- [X] T-R02G2101-004 [P] [US1] [US2] [US3] Create — Verified 2026-11-27: host-3 exit=0, BinaryGardensPlayTests: 500 seeded traces replay, undo exact, every refusal reachable (.autonomy/migration/checks/R02-G21-01.host-3.json)
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensPlay.swift` (agent B: stages "loading, tutorial,
  playing, paused, won, failed, result"; the arrangement from the level; `ring(star, index)`, `phase(star, step)`,
  `luminosity(star, index)` and `tilt(step)` validated in the order stage, previous fingerprint, action ("star not 1 …
  2 (index 0 … 1 in code); ring index outside the ring radii, phase outside 0 … 47, luminosity index outside the
  levels, tilt outside 0 … T_max; the control is locked (tilt locked when T_max = 0); the value is unchanged; the new
  arrangement breaks the minimum separation at a tick of 0 … 47"), budget ("no action left (actions spent = budget).
  `run` never checks the budget"), spending 1 action and recomputing the report; `run` spending nothing and ending the
  level won or failed with the judge's failure; records with previous and next fingerprints; full undo and redo (from
  failed back to playing with the arrangement before the run, actions spent unchanged, recorded; won is final; "Redo
  after an undo from failed re-runs the run and ends failed again with the same failure"); replay ("a replayed chain
  must start at the initial fingerprint and link every next to the following previous")) with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPlayTests.swift` (known arrangements win on the
  run on 500 seeded fixtures (SC-R02G2101-001); each failure named; the budget refusal on the exact action with the run still allowed; 500 seeded traces replay;
  undo restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G2101-005 [P] [US4] Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensPuzzle.swift` — Verified 2026-11-27: host-4 exit=0, BinaryGardensPuzzleTests: 200 walks against the play, 120 moves on the largest level (.autonomy/migration/checks/R02-G21-01.host-4.json)
  (agent C: `PuzzleRules`: State = position (arrangement, actions spent), Move = an arrangement action; legal moves
  "every legal arrangement action while actions are left" in the order of research R14 (star 1 then star 2, rings
  ascending, phases 0 … 47, luminosities ascending, then tilts 0 … T_max; at most 120); goal "the predicted run wins";
  rulesID "r02-g21-binary-gardens") with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPuzzleTests.swift` (agreement with the play on 200
  walks); `--name host-4`
- [X] T-R02G2101-006 [P] Create — Verified 2026-11-27: host-5 exit=0, nine BinaryGardens boundary invariant tests, seed 2_506 (.autonomy/migration/checks/R02-G21-01.host-5.json)
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensInvariantTests.swift` (agent D:
  `testBinaryGardensTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_506); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G2101-007 Docs: `docs/architecture/binary-gardens.md` (new: rules), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-27: docs (architecture binary-gardens.md new, package README, automatedtesting) and round02-host-1, -2 (with BinaryGardens), -3c, -3e, -3f exit=0
  `docs/automatedtesting.md` (BinaryGardens in local chunk round02-host-2 and in CI half b); `--name round02-host-1`,
  `-2`, `-3c`, `-3e`, `-3f` (chunk 2 gains BinaryGardens: `swift test --package-path Packages/ExperiencesRound02
  --filter 'MoonlitMechanism|AcousticConstellator|HarmonicBridges|BinaryGardens'`; the other four filters unchanged)
- [X] T-R02G2101-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-27: rendering-27, rendering-26, experiences, host-full exit=0 (.autonomy/migration/checks/R02-G21-01.{rendering-27,rendering-26,experiences,host-full}.json)
  `--name host-full`
- [X] T-R02G2101-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-27: reference-1 exit=0 (.autonomy/migration/checks/R02-G21-01.reference-1.json)
- [X] T-R02G2101-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-27: reference-2 exit=0 (.autonomy/migration/checks/R02-G21-01.reference-2.json)
- [X] T-R02G2101-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-27: script-tests exit=0 (.autonomy/migration/checks/R02-G21-01.script-tests.json)
- [ ] T-R02G2101-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, ci.yml, error, sky, level, fixtures, docs) stay
with the lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement coverage:
FR-001, 002, 009, 013 → 002; FR-003, 004, 005, 014 → 002, 003; FR-006 … 008, 011 → 004; FR-010 → 005; FR-012 → 006;
SC-001 … 005 → 002 … 006; SC-006 → 007 … 011.

## Phase 7: Convergence

- [X] T-R02G2101-013 State in `specs/501-binary-gardens-playable-rule-kernel/spec.md` FR-R02G2101-014 and in — Verified 2026-11-27: host-6 exit=0; FR-014 and the data model state window 0 with start 0; SkyTests already pin it (aWindowOneTickShortOfTheRequirementAndTheWholeCycle) (.autonomy/migration/checks/R02-G21-01.host-6.json)
  `data-model.md` (`BinaryGardensWorldLight`) that a world with no comfortable tick reports window 0 with start tick 0
  (as `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSky.swift` does), and pin it in
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSkyTests.swift`; `--name host-6` per FR-R02G2101-014
  (partial)
- [X] T-R02G2101-014 Record in `specs/501-binary-gardens-playable-rule-kernel/contracts/api.md` the public names the — Verified 2026-11-27: contracts/api.md lists the public names beyond the contract with their reasons
  kernel exposes beyond the contract (memberwise initializers of Star, World, Arrangement, Point, WorldLight and Report;
  `BinaryGardensBand.isLethal` and `.words`; `BinaryGardensFailure.world`; `BinaryGardensLevel.startReport`,
  `grouped(_:)` and its range constants; `BinaryGardensSky.tableScale`, `positionScale`, `squaredScale`,
  `millifluxPerUnit`), each with its reason, per plan: contracts/api.md (unrequested)
