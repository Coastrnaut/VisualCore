# Tasks: R02-G13-01 — Acoustic Constellator: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G13-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G13-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_421, neighbouring checks seed 2_426; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the stars, their phases, the links and the coherence are the CPU reference the renderer of R02-G13-03
will consume).

## Phase 1: Setup

- [X] T-R02G1301-001 Baselines after the gate is ready: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree; rendering baseline is X-R02-G12's visualcore-rendering run
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is the latest
  recorded visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [X] T-R02G1301-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `AcousticConstellatorCore`, — Verified 2026-11-23: host (AcousticConstellatorLevelTests 14 tests: reason codes, every range and structural refusal with boundaries, gap reduction, coupling table = rounded 2 sin, orderParts = |sum e^(i pi phi/6)|^2 on 500 sets, exact comparison boundaries and 47k sweep, floor and clamp, snap at sigma vs sigma+1, disconnected and missing named, hold on the last tick, labels for isomorphic and non-isomorphic graphs, stored-form round trip and damage, 200 fixtures win by their known actions and not bare) exit 0, lead retest
  `AcousticConstellatorCoreTests`, product); create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorError.swift` (codes "r02-g13.level, .action,
  .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorDynamics.swift` (the 12-step clock; the
  signed gap reduced to −5 … 6; the coupling table "t(0 … 6) = 0, 1, 2, 2, 2, 1, 0" as integer literals; the tick "c =
  ⌊K · P / 4⌋ clamped to −1 … 1", all stars moved at once modulo 12; the pairwise gap table (a, b) for gaps 0 … 6 and
  n²R² = A + B√3; the exact comparison with θ; the snap "gap above σ"; the symbol's connectivity over the remaining
  links; the listen in the order "missing pairs, then per tick: move, snap, disconnection, coherence, hold"; the
  graph-isomorphism label over all orderings),
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorLevel.swift` ("3 … 8 stars" with x, y, z
  0 … 11, "rate 0 … 11", "phase 0 … 11"; "0 … 6 fixed links" and a "connected" symbol of "2 … 10" pairs, a < b, no self
  or repeated pair; "K 1 … 8", "degree limit 2 … 4", "link limit symbol size … 16", "snap limit 2 … 5", "threshold
  1 … n²", "hold 2 … 12", "window hold … 48", "budget 1 … 40", "difficulty 1 … 5", tutorial, seed, id; fixed links within
  the limits; stars, links and progress named in words (FR-R02G1301-013); JSON schema 1 with sorted keys and
  fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorFixtures.swift` (seeded levels with known
  winning actions) with `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorLevelTests.swift`;
  `--name host`

## Phase 3: Story 1 — link stars until they cohere as the symbol (P1) 🎯

- [X] T-R02G1301-003 [P] [US1] Create — Verified 2026-11-23: host-2 (AcousticConstellatorDynamicsTests 10 tests: independent reference — coupling from rounded sine, exhaustive exact comparison over 1.27M triples with rational sqrt3 bounds, ticks and order parameter on 500 levels within 1e-9, connectivity by relaxation, listens re-implemented from the spec, labels by brute force and under relabelling, hand cases) exit 0, lead retest
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorDynamicsTests.swift` (agent A: the
  coupling table equals 2·sin(πd/6) rounded; on 500 seeded levels, links and starting phases, every tick equals an
  independent step (pulls recomputed from the rounded sine, the step clamped), every order parameter equals
  |Σ e^{iπφ/6}|² in floating point within 10⁻⁹, every exact comparison agrees with rational bounds of √3 away from the
  boundary and with hand cases on it, every connectivity verdict equals repeated relaxation, every label equals a brute
  force over permutations and is equal for isomorphic graphs; hand cases: two linked stars of rates 1 and 3 lock at a
  gap of 2 with K = 2, a gap of σ holds and σ + 1 snaps, coherence exactly at θ and one below, a hold reached on the last
  tick and one tick short); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, budget, undo, redo, replay (P1)

- [X] T-R02G1301-004 [P] [US1] [US2] [US3] Create — Verified 2026-11-23: host-3 (AcousticConstellatorPlayTests 9 tests: stage table, 200 fixtures win on the exact listen, missing/disconnected/incoherent named, budget failure on the exact action, refusals in order leave the play unchanged, undo exact incl. from failed, 500+20 seeded traces replay and tampered traces refused) exit 0, lead retest
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorPlay.swift` (agent B: stages "loading,
  tutorial, playing, paused, won, failed, result"; links starting at the level's fixed links, phases at the level's
  starting phases; `link`, `unlink`, `nudge` and `listen` validated in the order stage, previous fingerprint, action
  (unknown star, self link, existing link, degree or link limit, removing a missing or fixed link, a nudge step other
  than ±1); each spends 1 action; a listen wins on its hold tick or fails `missing(pair)`, `disconnected(tick, link)` or
  `incoherent(longest run)`; after any other action a spent budget fails `budget(action index)`; the listen report and
  the label after every action; records with previous and next fingerprints; full undo and redo (from failed back to
  playing, recorded; won is final); replay) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorPlayTests.swift` (known actions win on
  the exact listen; each failure named with its pair, tick and link or run; budget failure on the exact action with one
  action either side; a listen on the last action wins; 500 seeded traces replay; undo restores exact fingerprints; every
  refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G1301-005 [P] [US4] Create — Verified 2026-11-23: host-4 (AcousticConstellatorRules 4 tests: initial position, move order, 200 seeded walks agree with the play step by step, terminal positions) exit 0, lead retest
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorRules.swift` (agent C: `PuzzleRules`: State
  = position (links, phases, actions spent, outcome), Move = AcousticConstellatorAction; legal moves while playing "every
  valid link (pair order), every valid unlink (pair order), every nudge (star, then −1, +1), then the listen") with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorRulesTests.swift` (agreement with the
  play on 200 walks); `--name host-4`
- [X] T-R02G1301-006 [P] Create — Verified 2026-11-23: host-5 (AcousticConstellatorInvariantTests 9 boundaries — time, input budget, goal, repeatability, undo, failure honesty, stability, save, renderer purity — each with a seeded neighbouring-input check, seed 2_426) exit 0, run with the real rules file, lead retest
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorInvariantTests.swift` (agent D:
  `testAcousticConstellatorTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each with
  a seeded neighbouring-input check, seed 2_426); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1301-007 Docs: `docs/architecture/acoustic-constellator.md` (new: rules),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1301-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1301-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1301-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1301-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1301-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, dynamics, level, fixtures, docs) stay with
the lead. MVP: Story 1. Requirement coverage: FR-001, 009, 013 → 002; FR-002, 003, 014 → 002, 003; FR-004 … 008, 011 →
004; FR-010 → 005; FR-012 → 006; SC-001 … 005 → 002 … 006; SC-006 → 007 … 011.
