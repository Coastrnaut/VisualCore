# Tasks: Simulation Lab — Phase 02 Cellular automata GPU parity

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/gpu.md](contracts/gpu.md), [quickstart.md](quickstart.md). Gate A16-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A16-P02 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may raise a system prompt.
Precedent: `specs/117-sl-p01-algorithms/tasks.md`.

## Phase 1: Setup

- [X] T-A16-201 Baseline: cite the A16-P01 evidence on the unchanged sources (`.autonomy/checks/A16-P01.{sl-ios27-3,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A16-P01 evidence cited on unchanged sources (no Packages change since the A16-P01 record 5664c0cc): .autonomy/checks/A16-P01.sl-ios27-3.json, A16-P01.app-unit.json, A16-P01.verify-27.json, all exit 0

## Phase 2: Story 1 — the automaton on the GPU

- [X] T-A16-202 [US1] Create `Packages/ExperiencesCreative/SimulationLab/Experience/{AutomatonGPU,SimulationShaders}.swift` per contracts/gpu.md and clarification 3 ("RGBA8, alive = red 255, dead = 0", `texelFetch` thresholded at 0.5, "neighbours wrap by index modulo the grid size", birth and survival as two 9-bit masks; load from a CPU `FieldGrid`, step by count, read back; make together, release together; a compile failure or incomplete target throws) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P02.sl-ios27.json exit 0 (41 core, 14 Swift Testing and 46 XCTest experience tests, 0 failures, slowest 0.95 s, iOS 27); AutomatonGPU (RGBA8 pair, int rule masks, wrap by index) exercised by AutomatonParityTests
- [X] T-A16-203 [US1] Wire it into `Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift` per clarification 2 (the setup-failure edge case: a compile failure or incomplete target fails the session through the host's failure state, covered by a test with an invalid shader source; load at setup, after context recreation or resize, and on any non-step change — family, preset, reset, restore, a step count that went down or jumped beyond 128; otherwise step by the engine's iteration delta; the automaton display samples the GPU field; the other families keep the CPU upload until A16-P03; drawing never changes the digest) with `ExperienceTests/{AutomatonParityTests,GPURebuildTests}.swift` (every cell equals the CPU reference after 1, 2, 10 and 100 GPU steps of a seeded automaton; GPU blinker period 2; GPU glider back after 4 × N steps; equality after `recreateContext` and after a resize; refused actions and reset reload) (FR-A16-201, 202, 204; SC-A16-201, 202, 204) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P02.sl-ios27.json exit 0 (41 core, 14 Swift Testing and 46 XCTest experience tests, 0 failures, slowest 0.95 s, iOS 27); AutomatonParityTests (0 differing cells after 1, 2, 10, 100 steps; blinker period 2; glider back after 4N) and GPURebuildTests (context recreation, resize, refusals, reset, restore, invalid-shader setup failure)

## Phase 3: Story 2 — pass isolation

- [X] T-A16-204 [US2] Create `Packages/ExperiencesCreative/SimulationLab/ExperienceTests/PassIsolationTests.swift` (`FieldPass.runObserver` over 10 frames of the running automaton: no run's output name is among its input names; step runs alternate between the two targets) (FR-A16-203; SC-A16-203) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P02.sl-ios27.json exit 0 (41 core, 14 Swift Testing and 46 XCTest experience tests, 0 failures, slowest 0.95 s, iOS 27); PassIsolationTests (10 frames: no run reads its output; steps alternate two targets; inputIsOutput refused)

## Phase 4: Story 3 — the Gray-Scott fixture

- [X] T-A16-205 [P] [US3] Create `Packages/ExperiencesCreative/SimulationLab/Experience/GrayScottGPU.swift` (its step shader kept in this file, so `SimulationShaders.swift` has one writer; RGBA16F pair, u red, v green, `highp` step with the five-point stencil, wrap by index, Dᵤ 0.16, Dᵥ 0.08) and `Packages/ExperiencesCreative/SimulationLab/ExperienceTests/GrayScottToleranceTests.swift` ("16 × 16 seeded grid … 10 steps … at most 0.01 against `float16` or `float16TowardZero`"; fails with "Floating-point render targets are not available" without float support) (FR-A16-210; SC-A16-205) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P02.sl-ios27.json exit 0 (41 core, 14 Swift Testing and 46 XCTest experience tests, 0 failures, slowest 0.95 s, iOS 27); GrayScottToleranceTests: max |GPU − CPU| after 10 steps on 16 × 16 = 0.0032 (float16) and 0.0 (float16TowardZero), tolerance 0.01

## Phase 5: Records and evidence

- [X] T-A16-206 Contract `docs/apps/simulation-lab/visualcore-contract.json`: G-CA-GPU closed by "A16-P02" (the Gray-Scott fixture recorded in G-RDWAVE-GPU's notes); rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app simulation-lab --render`) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P02.contract.json exit 0; G-CA-GPU closed by A16-P02; the Gray-Scott fixture recorded in G-RDWAVE-GPU; no row became available (each still has an open gap)
- [ ] T-A16-207 Simulation Lab tests on sim-27.2 (`--name sl-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SimulationLabCoreTests SimulationLabExperienceTests`) and the documented-API check (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/SimulationLab`) (SC-A16-201–205)
- [ ] T-A16-208 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a16.simulation-lab --runtime 27`) (FR-A16-220)
- [ ] T-A16-209 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A16-210 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A16-P02; update README.md (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A16-201 → 202 → 203 → 204; 201 → 205 (independent files); {203, 204, 205} → 206 → 207 → 208 → 209 → 210.

## Parallel examples

Agent A: T-A16-202, 203 (GPU type, shaders, presenter, parity and rebuild tests). Agent B: T-A16-205 and, after A,
T-A16-204. Lead: contract, runs, commits.

## Implementation strategy

MVP: the automaton on the GPU with parity (202, 203); isolation (204) and the fixture (205) close the phase.
