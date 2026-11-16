# Tasks: Simulation Lab — Phase 05 Numerical validation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/report.md](contracts/report.md), [quickstart.md](quickstart.md). Gate A16-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A16-P05 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may raise a system prompt.
Precedent: `specs/120-sl-p04-ui-presets-capture/tasks.md`.

## Phase 1: Setup

- [X] T-A16-501 Baseline: cite the A16-P04 evidence on the unchanged sources (`.autonomy/checks/A16-P04.{sl-ios27-2,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A16-P04 evidence cited on unchanged sources (no Packages, Apps or project.yml change since the A16-P04 record 6821e3ee): .autonomy/checks/A16-P04.sl-ios27-2.json, A16-P04.app-unit.json, A16-P04.verify-27.json, all exit 0

## Phase 2: Foundational — presenter accessors

- [X] T-A16-502 Add documented `ownedTargetBytes` (display target + automaton, Gray-Scott and wave pairs; `PingPongTarget.bytes` and the target's handle bytes) and `maxGPUStepsInFrame` (the largest per-frame GPU step delta since setup, automaton and float mirrors) to `Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift` (data-model.md) (FR-A16-503) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P05.sl-ios27.json exit 0 (62 core, 23 Swift Testing and 62 XCTest experience tests, 0 failures, slowest 6.6 s, iOS 27); ownedTargetBytes (180,224 bytes in the report) and maxGPUStepsInFrame (16 in the report) in SimulationPresenter; also the paint-count reload found by BoundaryRuleTests (SimulationCore.paintCount, not saved or digested; a paint then a step in one frame was stepped from the unpainted field)

## Phase 3: Story 1 — the validation report

- [X] T-A16-503 [US1] Create `Packages/ExperiencesCreative/SimulationLab/ExperienceTests/SimulationValidationTests.swift` per contracts/report.md and clarifications Q1–Q5. — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P05.sl-ios27.json exit 0 (62 core, 23 Swift Testing and 62 XCTest experience tests, 0 failures, slowest 6.6 s, iOS 27); SimulationValidationTests (6.6 s) generated docs/apps/simulation-lab/validation-report.md and the full run matched it: mirrors 0.0000 / 0.0015 / 0.0000 against 0 / 0.01 / 0.01; fixtures 0.0000 against float16; 600 iterations at each limit 0 non-finite cells on CPU and GPU; 1 % beyond refused with the sentences; 16 GPU steps per frame at most (cap 128); 180,224 bytes (bound 262,144)
  - **Running mirrors:** per family, 120 frames at ×4 through the presenter, with max |GPU − CPU| after every frame;
    tolerances 0 and 0.01.
  - **Fixtures:** the 16 × 16 ten-step runs, against both roundings.
  - **Limits:** 600 iterations at Δt 1.5625 and at c 1, Δt 1/√2, on the CPU and on the GPU pair, all finite; 1 % above
    each limit refused, with the sentences quoted.
  - **Bounds:** `maxGPUStepsInFrame` ≤ 128; `ownedTargetBytes` ≤ 262,144; the registry's `totalBytes` ≤
    `budget.total`.
  - **Steps per second:** 600 CPU iterations per family timed with `ContinuousClock` and labelled "simulator figure,
    not a device claim".
  - **Report:** render `docs/apps/simulation-lab/validation-report.md`, written when `UPDATE_VALIDATION_REPORT=1`.
    Otherwise compare the deterministic lines (all lines outside the steps-per-second section) with the committed
    file; a difference fails with "Regenerate the report with UPDATE_VALIDATION_REPORT=1."
  - Without floating-point targets, the test fails with "Floating-point render targets are not available" and
    writes no report.
  - The report states that a jump beyond 128 iterations loads the mirror instead of stepping it (the A16-P02 rule;
    `GPURebuildTests`).
  - Generate and commit the report.

  (FR-A16-501–503; SC-A16-501–503)

## Phase 4: Story 2 — size change and boundaries

- [X] T-A16-504 [P] [US2] Create `Packages/ExperiencesCreative/SimulationLab/ExperienceTests/SizeChangeTests.swift`: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P05.sl-ios27.json exit 0 (62 core, 23 Swift Testing and 62 XCTest experience tests, 0 failures, slowest 6.6 s, iOS 27); SizeChangeTests: per family a resize keeps resourceBuildCount, reloads the mirror and the field is within tolerance with the square fitted to the new canvas; a recreation raises resourceBuildCount by one and reloads, within tolerance
  - per family, mid-run (paused after frames), a canvas resize to a new size keeps `resourceBuildCount` and the GPU
    field after the next frame is within the family's tolerance of the CPU field, and the drawn square fits the new
    canvas (`lastSquare`);
  - a `recreateContext` raises `resourceBuildCount` by one, loads every mirror and leaves the field within tolerance.

  (FR-A16-504; SC-A16-504)
- [X] T-A16-505 [P] [US2] Create `Packages/ExperiencesCreative/SimulationLab/ExperienceTests/BoundaryRuleTests.swift`: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P05.sl-ios27.json exit 0 (62 core, 23 Swift Testing and 62 XCTest experience tests, 0 failures, slowest 6.6 s, iOS 27); BoundaryRuleTests: a glider crosses columns 63 and 0 on the GPU equal to the CPU and is back after 256 generations; a reaction-diffusion disc at (0, 0) wraps to the opposite edges on the GPU within 0.01 (its first run failed and exposed the paint reload bug fixed in T-A16-502); wave edges 0 on GPU and CPU
  - the automaton on the GPU: a glider placed by `sim.paint` at the right edge wraps to the left after 4 × 64
    generations, equal to the CPU;
  - reaction-diffusion: a disc painted at cell (0, 0) shows values on the opposite edges after one GPU step, equal to
    the CPU within 0.01;
  - the wave: edges stay 0 (cites `WaveBorderTests`).

  (FR-A16-505)

## Phase 5: Records and evidence

- [X] T-A16-506 Contract `docs/apps/simulation-lab/visualcore-contract.json`: G-VALIDATION closed by "A16-P05" (the report on iOS 27.2; the iOS 26 section at X-A16; device figures in the device campaign); rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app simulation-lab --render`) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P05.contract.json exit 0; G-VALIDATION closed by A16-P05 (report on iOS 27.2; iOS 26 section at X-A16; device figures in the device campaign); M09, M16 and M26 available
- [X] T-A16-507 Simulation Lab tests on sim-27.2 (`--name sl-ios27`; the slowest test under 10 s), documented API (`--name documented-api`), packages (`--name packages`), scripts (`--name scripts`) (SC-A16-505) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P05.sl-ios27.json exit 0 (slowest test 6.6 s), A16-P05.documented-api.json, A16-P05.packages.json and A16-P05.scripts.json exit 0
- [X] T-A16-508 App build and unit (`--name app-unit`) and runner (`--name verify-27`) (FR-A16-506) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P05.app-unit.json exit 0 and A16-P05.verify-27.json exit 0 (the runner's scenarios pass on iOS 27.2, 0 failures)

## Dependencies

- T-A16-501 runs first, then T-A16-502.
- T-A16-503 needs T-A16-502.
- T-A16-504 and T-A16-505 are independent test files (agents).
- T-A16-506 through T-A16-508 run last.

**Review checkpoint:** after T-A16-503 (the report). **MVP:** Story 1.
