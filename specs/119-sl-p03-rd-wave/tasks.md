# Tasks: Simulation Lab — Phase 03 Reaction-diffusion and wave algorithms

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/gpu.md](contracts/gpu.md), [quickstart.md](quickstart.md). Gate A16-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A16-P03 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may raise a system prompt.
Precedent: `specs/118-sl-p02-automata-gpu/tasks.md`.

## Phase 1: Setup

- [X] T-A16-301 Baseline: cite the A16-P02 evidence on the unchanged sources (`.autonomy/checks/A16-P02.{sl-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A16-P02 evidence cited on unchanged sources (no Packages, Apps or project.yml change since the A16-P02 record 90974faa): .autonomy/checks/A16-P02.sl-ios27.json, A16-P02.app-unit.json, A16-P02.verify-27.json, all exit 0

## Phase 2: Foundational — the time-step action and rule code

- [X] T-A16-302 Add `sim.timestep [0.05…2.0]` and `SimulationRule.unsupported = "a16.unsupported"` to `Packages/ExperiencesCreative/SimulationLab/Experience/Adapter/SimulationCore.swift` per contracts/gpu.md and clarification Q4. Behaviour: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P03.sl-ios27.json exit 0 (41 core, 20 Swift Testing and 33 XCTest experience tests, 0 failures, slowest 1.98 s, iOS 27); TimeStepTests: limits accepted, 1 % above refused with a16.unstable and the sentence, below-range and automaton a16.invalid-choice, field kept; the sources of T-A16-302 to 307 land in this commit (one presenter file is shared by them)
  - "Δt above 1.5625 … `a16.unstable`"; "C = c · Δt exceed 1/√2 … `a16.unstable`";
  - outside the family's own range → `a16.invalid-choice`; the automaton → `a16.invalid-choice`;
  - an accepted Δt keeps the field, the step count, running and speed.

  Then update the header, `actionIDs`, `valueCounts` and `controls`, and regenerate `scenario-manifest.json` with the
  control id. Tests in `ExperienceTests/TimeStepTests.swift`:
  - accepted at each limit, refused 1 % above it with the code;
  - the state is unchanged after a refusal, and the field is kept after an acceptance;
  - automaton refusal; below-range refusal.

  (FR-A16-330; SC-A16-304)

## Phase 3: Story 1 — the float fields on the GPU

- [X] T-A16-303 [P] [US1] Create `Packages/ExperiencesCreative/SimulationLab/Experience/WaveGPU.swift` per contracts/gpu.md and clarification Q1: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P03.sl-ios27.json exit 0 (41 core, 20 Swift Testing and 33 XCTest experience tests, 0 failures, slowest 1.98 s, iOS 27); WaveGPU (RGBA16F, uⁿ red, uⁿ⁻¹ green, zero edges) and the reaction and wave display programs, exercised by FloatFieldToleranceTests and FloatMirrorTests; both step shaders round to the nearest half in GLSL, so the GPU equals the float16 CPU reference (max 0.0)
  - "One RGBA16F ping-pong pair … current value uⁿ in red and the previous uⁿ⁻¹ in green"; the step writes (uⁿ⁺¹, uⁿ);
  - `uCourant2` and `uKeep`; "writes 0 for any cell on the edge"; `texelFetch` without wrap;
  - throws `floatTargetsUnavailable` or `compile`; its step shader lives in this file.

  Add `reactionDisplay` and `waveDisplay` to `Experience/SimulationShaders.swift`: the `SimulationPalette` stops as
  uniforms, v / 0.5 for reaction-diffusion, the height clamped to −1…1 for the wave.
- [X] T-A16-304 [US1] Wire the Gray-Scott and wave mirrors into `Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift` per clarification Q3: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P03.sl-ios27.json exit 0 (41 core, 20 Swift Testing and 33 XCTest experience tests, 0 failures, slowest 1.98 s, iOS 27); FloatFieldToleranceTests max |GPU − CPU| after 10 steps on 16 × 16: reaction-diffusion 0.0 (float16) / 0.0032 (toward zero), wave 0.0 / 0.0066, tolerance 0.01; WaveBorderTests 60 of 60 edge cells 0 after 100 steps; FloatMirrorTests (≤ 0.01 over 60 running frames with a reload after 64 steps, loads after recreation, resize, preset, reset and time step, display within ±1 of the palette, no pass reads its output)
  - load at setup, recreation, resize, any non-step change, and "whenever 64 GPU steps have run since the last load";
  - otherwise step by the engine's iteration delta (≤ 128 per frame); draw through the family's display;
  - counters `floatLoadCount` and `floatStepCount`; drawing never changes the digest.

  Tests:
  - `ExperienceTests/FloatFieldToleranceTests.swift`: both families, 10 GPU steps on 16 × 16, "the smaller of the two
    maxima is ≤ 0.01".
  - `ExperienceTests/WaveBorderTests.swift`: 100 GPU steps on 16 × 16, every edge cell exactly 0.
  - `ExperienceTests/FloatMirrorTests.swift`:
    - a reload after 64 steps;
    - reloads after recreation, resize, preset, reset and time step;
    - GPU display pixels within ±1 per channel of `SimulationPalette.rgba`;
    - `FieldPass.runObserver` shows no run reading its own output.

  (FR-A16-301–303; SC-A16-301, 302)

## Phase 4: Story 2 — no floating-point targets

- [X] T-A16-305 [US2] In `SimulationPresenter.swift` and `Experience/SimulationControls.swift`: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P03.sl-ios27.json exit 0 (41 core, 20 Swift Testing and 33 XCTest experience tests, 0 failures, slowest 1.98 s, iOS 27); FloatUnsupportedTests (forced no support: no Gray-Scott or wave pair or display, both families refused with a16.unsupported and the sentence, a restored reaction-diffusion state drawn from the CPU upload with the sentence in the status line)
  - probe `FloatRenderSupport.detect(in:)` in `setup` (seam `forceFloatUnsupported`);
  - without support, make no float or 8-bit pair for the two families;
  - `send` refuses `sim.family` 1 or 2 with `a16.unsupported` and the unsupported sentence, and the controls disable
    those families;
  - a restored state of either family is drawn from the CPU upload with the sentence in the status line.

  Tests in `ExperienceTests/FloatUnsupportedTests.swift`: no Gray-Scott or wave pair exists, the sentence appears, the
  refusal code, and the restored state is drawn. (FR-A16-310; SC-A16-303)

## Phase 5: Story 3 — the legend

- [ ] T-A16-306 [P] [US3] Create `Packages/ExperiencesCreative/SimulationLab/Experience/SimulationLegend.swift`:
  - `SimulationLegendValues.of(_:kind:)` gives the minimum and maximum of v or the height, or the alive and dead
    counts, plus `words`;
  - the `SimulationLegend` view: a colour bar on an opaque panel at the bottom-leading corner, caption style with
    Dynamic Type, hidden from VoiceOver.

  Return it from the presenter's `makeCanvasOverlay(_:)`, and append `words` to the canvas description
  (`SimulationCore` / `describe`). Tests in `ExperienceTests/LegendTests.swift`: the values equal the field's extremes
  for each family, and the description contains them. (FR-A16-320; SC-A16-305)

## Phase 6: Story 4 — the explained refusal

- [ ] T-A16-307 [US4] `SimulationPresenter.answerWords` gives the refusal's own sentence for `sim.timestep`:
  - `SimulationRefusal.reactionStep` or `.courant`, the range sentence, or the one-generation sentence;
  - for `sim.family` with `a16.unsupported`, the unsupported sentence.

  Add a time-step row to `SimulationControls.swift` (a stepper of 0.05 per tap, through the presenter). The status line
  states the time step. Extend `TimeStepTests.swift`: the message equals "The wave step is too large: the Courant number
  must stay at or below 0.707." and the reaction sentence naming 1.5625. (FR-A16-330; SC-A16-304)

## Phase 7: Records and evidence

- [ ] T-A16-308 Contract `docs/apps/simulation-lab/visualcore-contract.json`: G-RDWAVE-GPU closed by "A16-P03"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app simulation-lab --render`)
- [ ] T-A16-309 Simulation Lab tests on sim-27.2 (`--name sl-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SimulationLabCoreTests SimulationLabExperienceTests`), the documented-API check (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/SimulationLab`), the package check (`--name packages -- python3 scripts/check_experience_packages.py`) and script tests (`--name scripts -- python3 scripts/test_scripts.py`); the slowest test in the log is under 10 s (SC-A16-301–305)
- [ ] T-A16-310 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a16.simulation-lab --runtime 27`) (FR-A16-340)

## Dependencies

- T-A16-301 runs first, then T-A16-302.
- T-A16-303 and T-A16-306 can run in parallel.
- T-A16-304 needs T-A16-303.
- T-A16-305 needs T-A16-304.
- T-A16-307 needs T-A16-302 and T-A16-305.
- T-A16-308 through T-A16-310 run last.

**Review checkpoints:** after T-A16-304 (the tolerance holds) and after T-A16-307 (the gates are met). **Parallel
example:** Agent A writes `WaveGPU` and the display programs; Agent B writes `SimulationLegend`; Agent C writes the test
files. The lead edits the presenter, the core and the controls. **MVP:** Story 1 (T-A16-303, 304).
