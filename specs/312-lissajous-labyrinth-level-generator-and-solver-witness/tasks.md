# Tasks: R02-G02-02 — Lissajous Labyrinth: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
or {device} tasks (pure logic and host-generated content). Fixture seed 2_312; tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0202-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`, the isolated — Verified 2026-11-20: 2026-11-20 R02-G02-02.baseline-host/timing/round02 exit 0
  timing run (`--name baseline-timing`) and `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`;
  the rendering baseline is R02-G01-05's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0202-002 Add `generation(Int)` ("r02-g02.generation") and `witness(String)` ("r02-g02.witness") to — Verified 2026-11-20: 2026-11-20 host-1b exit 0 (whole round-two package; 'host' attempt failed only on the then-missing witness files and unpinned digest)
  `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthError.swift`; create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthManifest.swift`
  (LissajousLabyrinthManifestEntry "number 1 … 100, seed UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from
  `python3 scripts/planning_index.py levels --experience R02-G02` with the source line) and
  `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthDifficulty.swift` ("shortest, winningSettings, clearance > 0, work"; `clearance(_:level:)`
  = min over samples and obstacles of squared distance − squared radius); the `LissajousLabyrinthSolution` type in
  `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSolver.swift` as the contract states (solver body by agent A); `--name host -- swift test
  --package-path Packages/ExperiencesRound02` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G0202-003 [P] [US1] Implement `LissajousLabyrinthSolver` in `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSolver.swift` — Verified 2026-11-20: 2026-11-20 host-2 exit 0 (9 solver tests, 8.8 s: exact fast decision equals the kernel verdict on all 14,080 settings of one level and on winners plus 440 samples of 20 more; shortest equals a plain BFS on 10 levels)
  (`legalSettings` 14,080 ordered (a, b, φ, ψ); the sound checkpoint-box prefilter of research R2 with separable
  4,096-tick bit sets; the kernel's exact verdict for every survivor; work = exact verdicts; breadth-first search over
  `LissajousLabyrinthRules.moves` to the nearest winning setting, ties by (a, b, φ, ψ) ascending) with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthSolverTests.swift` (seed 2_312: the exact fast decision equals the kernel verdict on all
  legal settings of 1 level (3 obstacles, > 1,000 winners) and on every winner plus 440 sampled settings of 20 more; shortest equals a plain BFS over
  the decided winning set on 10 levels; actions
  replay on `LissajousLabyrinthRules` through legal states to a win; nil when no winner; determinism); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G0202-004 [US2] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthGenerator.swift` (LissajousLabyrinthBandProfile — Verified 2026-11-20: 2026-11-20 host-3 exit 0 (3 generator tests, 1.4 s)
  "checkpoints 2, 3, 4, 5, 6 of radius 512, 448, 384, 320, 256; obstacles 2, 3, 4, 6, 8; shortest 1–2, 2, 2–3, 3, 3–4",
  LissajousLabyrinthGenerated, `generate` with candidates k = 0 … 63 from `SeedDerivation.derive(seed, index: k)`, id
  `lissajous-labyrinth-NNN`, allowance = budget, tutorial for 1 … 3, `.generation(number)` beyond 64; `catalogDigest`)
  with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthGeneratorTests.swift` (determinism; band ranges; budget; skipped recorded; a profile
  that cannot be met is refused); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G0202-005 [P] [US4] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthWitness.swift` (schema 1; built by replaying the — Verified 2026-11-20: 2026-11-20 host-4 exit 0 (11 witness tests)
  solution on a `LissajousLabyrinthPlay`: fingerprints after begin/tutorial and each action; terminal visit ticks and
  clearance; near miss and non-coprime counterexample per clarification Q4; sorted-key pretty JSON with a trailing
  newline; `decode` refuses newer, damaged and non-replaying witnesses) with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthWitnessTests.swift` (round trip byte for byte; edited action, fingerprint, level,
  terminal, counterexample and difficulty refused; newer schema and damaged JSON refused; the near miss loses with a named
  verdict; the non-coprime counterexample is refused by the rules; frequencies 1 handled); `--name host-4`
- [X] T-R02G0202-006 [US2] [US3] [US4] Create `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthCatalogTests.swift` (100 entries, 20 per — Verified 2026-11-20: 2026-11-20 host-5 exit 0 (catalog: pinned digest 9c1d5652…e96e, progression, band means shortest 1.25/2/2.95/3/4 and winners 785/55/3.5/1.5/1, kernel cross-check on levels 1, 11 … 91, 100 witness files byte for byte, INV-06)
  band; the catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on shortest; band means
  of shortest never fall and of winning settings never rise; on levels 1, 11, 21, … 91 (two per band) the winning set
  agrees with the kernel verdict on every winner plus 440 sampled settings and the shortest equals a plain BFS over the
  decided winning set (SC-R02G0202-002); each witness equals
  `docs/games/lissajous-labyrinth/levels/NNN.witness.json` byte for byte, one test per band, written only with
  `LISSAJOUS_LABYRINTH_WRITE_WITNESSES=1`) and generate the 100 files; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G0202-007 Docs: `docs/architecture/lissajous-labyrinth.md` (generator, solver, witness), — Verified 2026-11-20: 2026-11-20 round02-host exit 0; docs/architecture/lissajous-labyrinth.md content section, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md` (witness regeneration); `--name round02-host --
  swift test --package-path Packages/ExperiencesRound02`
- [X] T-R02G0202-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-20: 2026-11-20 rendering-27, rendering-26 (with the VisualCoreRendering macOS floor), experiences, host-full, app-unit exit 0
  `--name host-full` and `--name app-unit`
- [X] T-R02G0202-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-20: 2026-11-20 reference-1 exit 0
- [ ] T-R02G0202-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0202-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0202-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 005 (agent B, against the contract; replays tested with a hand-built fixture)} → 004 (needs
003) → 006 (needs 004, 005) → 007 … 012. Shared files (error, manifest, difficulty, generator, catalog tests, witness
files, docs) stay with the lead. MVP: Story 1.
