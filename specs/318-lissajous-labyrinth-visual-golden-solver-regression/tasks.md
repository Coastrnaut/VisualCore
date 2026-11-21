# Tasks: R02-G02-08 — Lissajous Labyrinth: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_318;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0208-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G0208-002 [P] [US1] Create `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-21: 2026-11-21 host exit 0: LissajousLabyrinthRegressionSolverTests 9/9 (five bands: each generated level equals its witness byte for byte, the witness replays to a win with its recorded fingerprints, solve gives exactly the certified shortest with matching actions, work at most 14,080 (largest recorded 3,609) and the recorded winning-setting count; twelve alterations of levels 7 and 86 each fail naming the level and the part). Spec SC-R02G0208-001 corrected from 3,840 to 14,080
  level in five bands of 20, "the generated level equals its witness's level; the witness replays to a win in exactly
  its recorded actions with its recorded fingerprints; solve returns exactly the certified shortest whose actions win,
  work ≤ 14,080 and the witness's winning-setting count"; twelve named alterations of clarification Q2 each fail naming
  the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  LissajousLabyrinthRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G0208-003 [US2] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-21: 2026-11-21 LissajousLabyrinthGolden builds (DEBUG or automation only); golden-frames.json generated with LISSAJOUS_LABYRINTH_WRITE_GOLDEN=1 (schema 1, 16 frames, 128 path samples each, 63,861 bytes); LissajousLabyrinthGolden added to RELEASE_FORBIDDEN; proven by host-2
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0, plus the hero frame; at 1,152 × 768 with the authored camera:
  every 32nd lap tick's sample, each checkpoint ring's band point and state colour, each obstacle's centre and colour,
  each dial ring's centre and knob, the night colour; positions rounded to 1/8 px; colours 8-bit sRGB; JSON with sorted
  keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/LissajousLabyrinth/golden-frames.json` with `LISSAJOUS_LABYRINTH_WRITE_GOLDEN=1`, and add `LissajousLabyrinthGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G0208-004 [P] [US2] Create `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-21: 2026-11-21 host-2 exit 0: LissajousLabyrinthRegressionGoldenTests 7/7 (fixed golden set; deterministic descriptions; every frame matches the pinned file; each pinned digest equals its description's; missing, unreadable, schema-2 and unknown frames named; a 2-quantum move, a colour and a tier detail change fail, one quantum passes; a hand-edited description with its old digest refused)
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinthRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G0208-005 [US2] [US3] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthThreadScene.swift` (`liveObjectCount`: renderers — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: LissajousLabyrinthRegressionGoldenFrameTests (16 golden frames rendered: the drawn snapshot equals the described one; path samples, rings, obstacles and background within the 2 px / 0.12 / 0.05 tolerances; dial rings and knobs inside the frame) and LissajousLabyrinthRegressionMemoryTests (12 cycles, isolated run: 31.4 … 33.6 MB, within 16 MB of cycle 1; no renderers after each warning and close, rebuilt on the next frame); all 53 Lissajous experience tests. Found on the way: a still drawn at the same time as the last frame froze the fades, so a frame time that does not move forward now settles the lights
  held, 0 after release) and create `Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the 2 px, 0.12 and 0.05 tolerances; 12 open-draw-warn-close cycles with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_LISSAJOUS_LABYRINTH_MEMORY_ISOLATED=1`, readings printed otherwise; live renderers 0 after each close and
  warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G0208-006 [P] [US4] Create `scripts/lissajous_labyrinth_regression.py` and its test in `scripts/test_scripts.py`
  (agent D: host filter `LissajousLabyrinthRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Lissajous Labyrinth regression
  (host)" to `.github/workflows/ci.yml`; `--name regression -- python3 scripts/lissajous_labyrinth_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0208-007 Docs: `docs/architecture/lissajous-labyrinth.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g02.lissajous-labyrinth`
- [ ] T-R02G0208-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0208-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0208-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0208-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0208-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G0208-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
