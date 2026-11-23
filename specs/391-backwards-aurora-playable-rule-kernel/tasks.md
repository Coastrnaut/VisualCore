# Tasks: R02-G10-01 — Backwards Aurora: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G10-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G10-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_391, neighbouring checks seed 2_396; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the wave and its bends are the CPU reference the renderer of R02-G10-03 will consume).

## Phase 1: Setup

- [X] T-R02G1001-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline is X-R02-G09's visualcore-rendering run (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is X-R02-G09's visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [X] T-R02G1001-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `BackwardsAuroraCore`, `BackwardsAuroraCoreTests`, — Verified 2026-11-22: host (swift test --filter BackwardsAurora: BackwardsAuroraLevelTests 6 — reason codes, every range refusal incl. solved openings, stored form round trip and damaged/edited/newer refusals, hand-computed bends, seams, palindromes and distances, names in words, 500 fixtures whose known reversals restore the target without tearing and win only on the last) exit 0, lead
  product); create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraError.swift` (codes "r02-g10.level,
  .action, .noop, .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraWave.swift` ("N 12 … 32, each −64 … 64"; bends
  "b(k) for k in 1 … N − 2"; `reversed(start:end:)`; seam positions "{i − 1, i, j, j + 1} ∩ 1 … N − 2"; worst bend;
  palindrome test; distance "(Σ|s − t|, Σ|t|)", 0/1 for an all-zero target),
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraLevel.swift` ("target wave (same length and
  multiset)", "checkpoints (2 … 8 distinct sorted positions)", "bend limit L 1 … 64", "breaking limit B L … 128",
  "shortest section 2 … N", "longest section shortest … N", "budget 1 … 40", "difficulty 1 … 5", tutorial, seed, id;
  "the opening wave never already wins"; samples, checkpoints, bends and reversals left named in words
  (FR-R02G1001-013); JSON schema 1 with sorted keys and fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraFixtures.swift` (seeded levels with known winning
  reversals) with `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraLevelTests.swift`; `--name host`

## Phase 3: Story 1 — fold the aurora back (P1) 🎯

- [X] T-R02G1001-003 [P] [US1] Create `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraWaveTests.swift` — Verified 2026-11-22: host-2 (BackwardsAuroraWaveTests 8: 500 seeded waves incl. constant and extreme ones; reversal vs independent index formula; bends vs separate recomputation; bends outside the seams unchanged and inside ones carried in reverse; worst bend, smoothness, checkpoint matches, distance and palindromes vs brute force; seams vs brute-force sets for every section of 4 lengths) exit 0, lead retest; seams doc comment reworded per agent A
  (agent A: on 500 seeded waves and sections, the reversal equals an independent index formula; every bend equals a
  separate recomputation; comparing all bends before and after shows that no bend outside the seam positions changes;
  the worst bend, smoothness, checkpoint matches and the distance equal brute force; palindromes detected exactly);
  `--name host-2`

## Phase 4: Stories 2 and 3 — tear, budget, undo, redo, replay (P1)

- [X] T-R02G1001-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraPlay.swift` — Verified 2026-11-22: host-3 (25 tests incl. BackwardsAuroraPlayTests 11: stage table; 500 fixtures win on the exact last reversal with metrics vs an independent computation; win on the last reversal of the budget; hand seam bends: B survives, B+1 tears, lowest seam named, tear on reversal 2 names reversal 1; budget 1…5 on the exact reversal, undo from failed and redo; every refusal in order; exact undo/redo fingerprints; 500 seeded traces replay and tampered records refused) exit 0, lead retest. Tear-beats-win is vacuous (B ≥ L: a torn wave is never smooth); tested as a tearing reversal matching every checkpoint
  (agent B: stages "loading, tutorial, playing, paused, won, failed, result"; `reverse(start, end)` validated in the
  order stage, previous fingerprint, range and length, no-op; each accepted reversal spends one; after a reversal tear
  (first seam position beyond B, ascending), then win, then budget; failures tear (move, seam) and budget; records with
  previous and next fingerprints; full undo and redo (from failed back to playing, recorded; won is final); replay)
  with `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraPlayTests.swift` (known reversals win on the
  exact action; a seam bend equal to B survives and B + 1 tears; budget on the exact action with one reversal either
  side; a win on the last reversal wins; tear beats win; 500 seeded traces replay; undo restores exact fingerprints;
  every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G1001-005 [P] [US4] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraRules.swift`
  (agent C: `PuzzleRules`: State = position (wave, spent, outcome), Move = BackwardsAuroraAction; legal moves while
  playing "every valid, non-noop reversal in order of start, then end") with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraRulesTests.swift` (agreement with the play on 200
  walks); `--name host-4`
- [ ] T-R02G1001-006 [P] Create `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraInvariantTests.swift`
  (agent D: `testBackwardsAuroraTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_396); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1001-007 Docs: `docs/architecture/backwards-aurora.md` (new: rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1001-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1001-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1001-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1001-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1001-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, wave, level, fixtures, docs) stay with the
lead. MVP: Story 1.
