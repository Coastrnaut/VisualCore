# Tasks: R02-G12-01 — Harmonic Bridges: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G12-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G12-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_411, neighbouring checks seed 2_416; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the strings, their swings and the bridge graph are the CPU reference the renderer of R02-G12-03 will
consume).

## Phase 1: Setup

- [X] T-R02G1201-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree; rendering baseline is X-R02-G11's visualcore-rendering run (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is X-R02-G11's visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [X] T-R02G1201-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `HarmonicBridgesCore`, — Verified 2026-11-23: host exit 0 (HarmonicBridgesLevelTests 9: reason codes, every range refusal and accepted boundary, the swing table against 4 sin²(nπk/6), resonance hand cases [1,3,4,3,1] and [7,3,4,3,7], mode above 5, threshold met and one quarter short, reachability and broken-string hand cases, names in words, stored form round trip and damaged/edited/newer refusals, 500 fixtures valid); package gains HarmonicBridgesCore and its tests
  `HarmonicBridgesCoreTests`, product); create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesError.swift`
  (codes "r02-g12.level, .action, .noop, .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesResonance.swift` (the swing table "q(n, k) ∈ {0, 1, 3,
  4}" for modes 1 … 5 and samples 1 … 5 as integer literals; resonance "n · peg = F · length" with n in 1 … 5; swing
  E(k) = Σ w · q(n, k); a bridge when every E(k) ≥ threshold; the bridge graph per step and the start's breadth-first
  reachable set, islands in index order; the report), `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesLevel.swift`
  ("2 … 8 islands" with positions x 0 … 15, y 0 … 9; "1 … 12 strings" as a < b, "length 1 … 6", "peg 1 … 12", locked, no
  repeated pair; start ≠ goal; "1 … 4 steps of 1 … 3 tones", "frequency 1 … 72", "strength 1 … 3", distinct frequencies
  in a step; "threshold 1 … 12", "budget 1 … 60", "difficulty 1 … 5", tutorial, seed, id; strings, resonances and
  progress named in words (FR-R02G1201-013); JSON schema 1 with sorted keys and fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesFixtures.swift` (seeded levels with known winning
  actions) with `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesLevelTests.swift`; `--name host`

## Phase 3: Story 1 — tune strings until a path of bridges forms (P1) 🎯

- [X] T-R02G1201-003 [P] [US1] Create `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesResonanceTests.swift` — Verified 2026-11-23: host-2 exit 0 (HarmonicBridgesResonanceTests 8: swing table from exact quarters; every (length, peg, frequency) mode against enumeration; 1,502 seeded cases of resonance, swing, bridge, reachability by relaxation and broken step and string against an independent reference; hand cases incl. strength 2, mode above 5, threshold boundaries); agent A's tests retested by the lead
  (agent A: the swing table equals 4 sin²(nπk/6) computed from exact quarter values; on 500 seeded levels and peg
  assignments, every resonance equals enumerating n in 1 … 5 with n · peg == F · length, every swing equals an
  independent sum, every bridge equals the threshold rule, every reachable set equals repeated relaxation to a fixed
  point (no queue); hand cases: mode 1 alone [1, 3, 4, 3, 1], modes 2 and 3 together [7, 3, 4, 3, 7], a mode above 5 not
  resonant, the threshold exactly met and one quarter short); `--name host-2`

## Phase 4: Stories 2 and 3 — breaks, budget, undo, redo, replay (P1)

- [X] T-R02G1201-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesPlay.swift` — Verified 2026-11-23: host-3 exit 0 (HarmonicBridgesPlayTests 10: stage table; 500 fixtures win on the test after their tunings with reports equal to the level's; failing tests name step and string incl. no crossing string; budget failure on the exact action with one either side, a test on the last action wins; refusals in order; pluck as a query in words; exact undo/redo incl. from failed; canonical fingerprint; 500 seeded traces replay; tampered and mismatched records refused); agent B's play retested by the lead
  (agent B: stages "loading, tutorial, playing, paused, won, failed, result"; pegs starting at the level's; `tune` and
  `test` validated in the order stage, previous fingerprint, action (unknown string, peg out of range, locked string),
  no-op (tuning to the current peg); each spends 1 action; a test wins when the goal is reached in every step, else fails
  `broken(step, string?)` with the first failing step and the lowest-index non-bridge string across the start's reach;
  after any other action a spent budget fails `budget(action index)`; pluck as a query; the report after every action;
  records with previous and next fingerprints; full undo and redo (from failed back to playing, recorded; won is final);
  replay) with `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesPlayTests.swift` (known actions win
  on the exact test; a failing test names its step and string; budget failure on the exact action with one action either
  side; a test on the last action wins; 500 seeded traces replay; undo restores exact fingerprints; every refusal reason
  reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G1201-005 [P] [US4] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesRules.swift` — Verified 2026-11-23: host-4 exit 0 (HarmonicBridgesRulesTests 4: rules id and initial position; move order on the hand level (34 and 45 moves); 200 seeded walks agree with the play move for move (first 20 through the real apply for every candidate, the rest through its validation plus 8 real applies per step, for CI time); terminal positions have no moves); agent C's rules retested by the lead against agent B's play
  (agent C: `PuzzleRules`: State = position (pegs, actions spent, outcome), Move = HarmonicBridgesAction; legal moves while
  playing "every valid tuning (string, then peg order), then the test") with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesRulesTests.swift` (agreement with the play on 200
  walks); `--name host-4`
- [X] T-R02G1201-006 [P] Create `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesInvariantTests.swift` — Verified 2026-11-23: host-5 exit 0 (HarmonicBridgesInvariantTests 9: time, input budget, goal, repeatability, undo, failure honesty, stability, save, renderer purity, each with a seeded neighbouring check, seed 2_416; the kernel source scan covers Error, Resonance, Level, Play and Rules); agent D's tests retested by the lead against the real play and rules
  (agent D: `testHarmonicBridgesTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_416); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1201-007 Docs: `docs/architecture/harmonic-bridges.md` (new: rules), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-23: round02-host exit 0; docs/architecture/harmonic-bridges.md (new: rules), ExperiencesRound02 README Harmonic Bridges section, testing doc entry; validate_docs passes
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1201-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full exit 0
  `--name host-full`
- [X] T-R02G1201-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-23: reference-1 exit 0
- [X] T-R02G1201-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-23: reference-2 exit 0
- [ ] T-R02G1201-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1201-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, resonance, level, fixtures, docs) stay with
the lead. MVP: Story 1.
