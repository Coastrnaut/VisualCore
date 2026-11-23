# Tasks: R02-G10-02 — Backwards Aurora: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G10-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G10-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_392; tests stay short (< 10 s each; catalog certification in groups of 5 levels). No {owner} or {device} tasks (pure
logic); no GLSL in this feature.

## Phase 1: Setup

- [X] T-R02G1002-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline is R02-G10-01's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G10-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1002-002 Add `generation(Int)` ("r02-g10.generation") and `witness(String)` ("r02-g10.witness") to — Verified 2026-11-22: host (swift test --filter BackwardsAurora; the 41 existing tests unchanged and passing with the two new refusals, the 100-entry manifest and the difficulty; the solver and generator sources compile alongside and are tested at T-003/T-004) exit 0, lead
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraError.swift` (no other kernel change: generated
  levels stay inside R02-G10-01's ranges); create
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraManifest.swift` (BackwardsAuroraManifestEntry "number
  1 … 100, seed UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from `python3 scripts/planning_index.py
  levels --experience R02-G10` with the source line) and
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraDifficulty.swift` ("smallest, length, checkpoints,
  reversedSamples, longestSection, badBends, bendLimit, breakingMargin, work"); `--name host -- swift test
  --package-path Packages/ExperiencesRound02 --filter BackwardsAurora` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G1002-003 [US1] Implement `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSolver.swift` — Verified 2026-11-22: host-2 (BackwardsAuroraSolverTests 12: hand-built one- and two-section levels solved exactly at the bound; bound arithmetic; bound over budget gives nil; section lengths and tears respected; determinism and the work bound; 10 generated levels (two per band) solved at the bound and replayed to a win on a fresh play; independent checks: bad bends from second differences, no single reversal (any section, palindromes included) removing more than 4 from every witness state, exhaustive search of every shorter sequence on two band-1 levels; 24 seeded one-section openings) exit 0, lead retest
  (clarification Q2: `badBends` = interior positions with |b| > L; `lowerBound` = ⌈β / 4⌉; iterative-deepening
  depth-first search over sections in the rules' order (start, then end; lengths within the level's sections; no
  palindromes) with the bound starting at ⌈β / 4⌉, pruning when depth + ⌈β / 4⌉ > bound, torn or failed states as
  leaves, goal = the level wins; work = reversals evaluated, bound 20,000; nil when none found within the bound) and,
  after it, agent A's `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraSolverTests.swift` (seed
  2_392: hand-built levels with known answers; the solution's length equals the bound; it replays to a win through the
  play; the independent check (bad bends recomputed separately; brute force over every single reversal from sampled
  states shows none removes more than 4; exhaustive search of every shorter sequence on small levels); determinism; work
  bound honoured); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G1002-004 [US2] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraGenerator.swift` — Verified 2026-11-22: host-3 (BackwardsAuroraGeneratorTests 16: band profiles (N ≥ 4k + 2), breaking limits, ids; candidate and generation determinism; all 100 entries checked field by field per band (ids, budgets, tutorial, lengths, L = target worst bend, separated sections within the band's lengths, β = 4k, checkpoints inside differing positions, breaking limit, the solution wins, difficulty recomputed); skipped re-checked; placement shape; accepts on sloped and flat hand cases) exit 0, lead retest
  (BackwardsAuroraBandProfile "band 1: 14 … 16, 2 … 3, 2 … 4, 2, none (B = 128); band 2: 18 … 22, 3 … 4, 2 … 5, 3, none;
  band 3: 22 … 26, 4 … 5, 2 … 6, 4, 48; band 4: 26 … 30, 5 … 6, 2 … 6, 5, 32; band 5: 30 … 32, 6 … 7, 2 … 6, 6, 16 (B =
  min(128, L + margin))", `candidate(_:index:)` drawing in the order of clarification Q1 from `SeededRandom(seed:
  SeedDerivation.derive(seed, index: c))`: length, target (start −24 … 24, slope −3 … 3, change −1 … 1 kept within −4 …
  4, heights within −64 … 64), L = max(1, worst bend), k, up to 16 placements (section lengths within the band's range
  and what still fits, spare samples spread over the k + 1 gaps; first start ≥ 2, each start ≥ previous end + 3, last
  end ≤ N − 3), the first with no palindrome and all 4 seam bends above L kept (nil when none), opening = all sections
  reversed, checkpoints (band + 1 sections, one differing position each), B; BackwardsAuroraGenerated; `generate` with c
  = 0 … 255 keeping a candidate only when the solver certifies exactly k within the budget; id `backwards-aurora-NNN`,
  budget = manifest budget, tutorial for 1 … 3, difficulty = band, `.generation(number)` beyond 256; `catalogDigest` via
  `PuzzleCatalog.digest(id: "backwards-aurora", identities:)`) and, after it, agent C's
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraGeneratorTests.swift` (determinism; band
  profiles; separation and seam filters; β = 4k; budget; the solution wins; skipped recorded and re-checked); `--name
  host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G1002-005 [P] [US4] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraWitness.swift` — Verified 2026-11-22: host-4 (BackwardsAuroraWitnessTests 14: fixtures of bands 1–4 round trip byte for byte; parts equal the solver's and an independent replay; the near miss as recorded; edited actions, digests, fingerprints, level, smallest, bound, near miss, difficulty, number and skipped each refused by name; a different winning sequence refused by the solver re-run (.witness("solution")); newer, older and damaged forms refused; make refuses a losing solution, wrong bound and wrong difficulty) exit 0, lead retest
  (schema 1; built by replaying the solution's reversals on a `BackwardsAuroraPlay`: the 16-hex sample digest after
  every reversal, fingerprints after begin (and dismissTutorial) and each reversal; smallest and the bound (bad bends);
  the near miss (the witness minus its last reversal: not won, bad bends above 0); difficulty; skipped; sorted-key
  pretty JSON with a trailing newline; `decode` refuses newer, damaged and non-replaying witnesses and re-runs the
  solver on the decoded level, refusing a witness whose actions or work differ (`.witness("solution")`, feature 382's
  convergence lesson)) with `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraWitnessTests.swift`
  (round trip byte for byte; edited actions, digests, fingerprints, level, near miss and difficulty refused; newer
  schema and damaged JSON refused; the near miss behaves as recorded) by agent B; `--name host-4`
- [X] T-R02G1002-006 [US2] [US3] [US4] Create — Verified 2026-11-22: host-5 (all BackwardsAurora tests incl. BackwardsAuroraCatalogTests: 100 entries, 20 per band; pinned digest 6eb242e6…d06e; progression rule and band means; all 100 stored witnesses win on the last reversal and not one short; independent bad-bend recount and single-reversal brute force on two levels per band; full decode per band; 100 files byte for byte in 20 groups of 5) exit 0; the 100 witness files generated with BACKWARDS_AURORA_WRITE_WITNESSES=1
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraCatalogTests.swift` (100 entries, 20 per band;
  the catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on the smallest count; band
  means never fall; the independent check on two levels per band (SC-R02G1002-002); all 100 witnesses replay to a win;
  each witness equals `docs/games/backwards-aurora/levels/NNN.witness.json` byte for byte, in groups of 5 levels,
  written only with `BACKWARDS_AURORA_WRITE_WITNESSES=1`) and generate the 100 files; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1002-007 Docs: `docs/architecture/backwards-aurora.md` (content pipeline), — Verified 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02, 321 s) exit 0; architecture doc content pipeline section, ExperiencesRound02 README, testing doc lesson (simulate a generator's filters); validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1002-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1002-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1002-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1002-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1002-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → 003 (lead; agent A tests) → 004 (lead; agent C tests) → {005 (agent B), 006 (lead)} → 007 … 012.
Shared files (error, manifest, solver, difficulty, generator, catalog tests, witness files, docs) stay with the lead.
MVP: Story 1.
