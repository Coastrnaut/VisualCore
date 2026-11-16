# Tasks: Simulation Lab — Phase 04 Experiment UI, presets and capture

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/ui.md](contracts/ui.md), [quickstart.md](quickstart.md). Gate A16-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A16-P04 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may raise a system prompt.
Precedent: `specs/119-sl-p03-rd-wave/tasks.md`.

## Phase 1: Setup

- [X] T-A16-401 Baseline: cite the A16-P03 evidence on the unchanged sources (`.autonomy/checks/A16-P03.{sl-ios27-2,app-unit,verify-27-2}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A16-P03 evidence cited on unchanged sources (no Packages, Apps or project.yml change since the A16-P03 record 0988add5): .autonomy/checks/A16-P03.sl-ios27-2.json and A16-P03.verify-27-2.json (both on the final A16-P03 sources) and A16-P03.app-unit.json, all exit 0

## Phase 2: Foundational — pure core and actions

- [X] T-A16-402 [P] Add the pure core in `Packages/ExperiencesCreative/SimulationLab/Core/`, per data-model.md and contracts/ui.md: — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P04.sl-ios27.json exit 0 (62 core, 23 Swift Testing and 54 XCTest experience tests, 0 failures, slowest 4.3 s, iOS 27); SimulationBrushTests (8), SimulationHistogramTests (6), ExperimentPresetTests (7) and the A16-P01 reference suites (AutomatonRuleTests, GrayScottTests, WaveFieldTests) pass
  - `SimulationBrush.swift`: `PaintMode` and `SimulationModel.paint(x:y:mode:)`.
    - automaton: "tap toggles, drag sets alive";
    - reaction-diffusion: "u 0.25, v 0.5 in radius 2 (wrap)";
    - wave: "height 1 in the cell and 4 neighbours, current and previous, edges stay 0";
    - values rounded to the family's precision; "step count unchanged"; false outside 0…63.
  - `SimulationHistogram.swift`: 16 bins; automaton 0…1, RD v 0…1, wave −1…1; "finite out-of-range values clamped to
    the end bins"; "Σbins + nonFinite = cells".
  - `ExperimentPreset.swift`: schema 1, with "name ≤ 60", "annotation ≤ 200" and "license ∈ {original, public-domain}";
    the spec must be valid and 64 × 64; JSON with sorted keys; decode refuses damaged and newer files. The six bundled
    presets: Life (Conway 1970), HighLife (Thompson 1994), Seeds (Silverman), Spots and Mazes (Pearson 1993), all
    public-domain, and Pulse (original).
  - `SimulationModel.swift`: `public mutating func paint(x:y:mode:) -> Bool`, which applies
    `SimulationBrush.painted(_:kind:x:y:mode:)` (pure, in `SimulationBrush.swift`) because `field` is `private(set)`.

  Core tests in `CoreTests/{SimulationBrushTests,SimulationHistogramTests,ExperimentPresetTests}.swift`:
  - each brush's exact cells;
  - the histogram sums and clamping, and NaN counted apart;
  - preset round trip, damaged and newer files refused, bundled presets valid with an allowed license;
  - the A16-P01 tiny CPU reference fixtures still pass (FR-A16-403).

  (FR-A16-401, 403, 420, 430)
- [ ] T-A16-403 Add `sim.paint [x 0…63, y 0…63, mode 0…1]` and `sim.spec [family 0…2, a, b, Δt 0.05…2]` to `Packages/ExperiencesCreative/SimulationLab/Experience/Adapter/SimulationCore.swift`:
  - `sim.paint` is refused with `a16.invalid-choice` for a value that is not a whole cell or mode;
  - `sim.spec` builds the family's spec from a and b (rule index and 0, feed and kill, or speed and damping) with Δt,
    validates it with `SimulationSpec.refusal()`, and starts at step 0 with the same seed, running and speed.

  Update the header, `actionIDs`, `valueCounts` and `controls`; regenerate `scenario-manifest.json`; update
  `SimulationCoreTests` (the control list). Tests in `ExperienceTests/PaintTests.swift` (core part): a paint changes
  only the brush cells and keeps the step count; `sim.spec` with each bundled preset's values gives its spec; a refused
  spec changes nothing. (FR-A16-401, 430)

## Phase 3: Story 1 — paint and step exactly

- [ ] T-A16-404 [US1] In `Experience/SimulationPresenter.swift`:
  - `pointer(_:viewSize:port:)` maps a point to its cell through `square(width:height:grid:)`; nothing is sent outside
    the square;
  - a began-and-ended touch without moving to another cell sends `sim.paint [x, y, 0]`; moving sends
    `sim.paint [x, y, 1]` per newly entered cell, keeping the last cell per pointer id;
  - `cancelPointers` forgets the drags; `gestureActions = ["sim.paint"]`.

  Add the Seed row (column and row steppers defaulting to 32, a Seed button) to `Experience/SimulationControls.swift`.
  Tests:
  - `ExperienceTests/PaintTests.swift` (session part): a tap at a cell's centre changes the brush cells; a drag over
    three cells paints three; the Seed row's action equals the tap's; a tap outside sends nothing.
  - `ExperienceTests/StepExactTests.swift`: per family, paused, Step through `presenter.send` gives the field of one CPU
    `SimulationModel.step()` from the previous state and step + 1.

  (FR-A16-401, 402; SC-A16-401)

## Phase 4: Story 2 — inspector, label, spoken state, motion caps

- [ ] T-A16-405 [US2] Add an Inspector section to `SimulationControls.swift`: every parameter of `ParameterCatalog.definitions(for:)` with value, unit and range, and the time step with its limit. Add the approximation label with the three sentences of FR-A16-410 (the words in `SimulationCore`). The description keeps running or paused, the step and the values. Tests in `ExperienceTests/InspectorWordsTests.swift`: the three label sentences, the inspector rows per family (name, value, unit, range) and the description's running, step and values words. (FR-A16-410, 411)
- [ ] T-A16-406 [US2] Add the motion caps to `SimulationPresenter.swift` and `Experience/SimulationLabExperience.swift`:
  - the factory passes `reduceFlashing`;
  - the presenter's `speedCap(kind:)` is ×1 under Reduce Motion, and for the automaton ×0.25 under Reduce Flashing;
  - `send` refuses a faster `sim.speed` with `a16.reduced-motion` and "Faster speeds are off while Reduce Motion or
    Reduce Flashing is on.";
  - on activation and after a family change, a speed above the cap is lowered through `sim.speed`; the speed picker
    disables the capped entries.

  Tests in `ExperienceTests/MotionCapTests.swift`: the caps per setting and family, the refusal and its sentence, and
  the lowering on activation and on a family change.
  (FR-A16-412)

## Phase 5: Story 3 — histogram

- [ ] T-A16-407 [US3] In `SimulationPresenter.swift`, gate `SimulationHistogram` into the mirror: at most once every 15 frames while running, and at the next frame after a non-step change. `Experience/SimulationLegend.swift` draws the 16 bars. The description adds "most cells in bin k (low…high)". Tests in `ExperienceTests/HistogramGateTests.swift`: over 60 running frames, at most 4 updates; a paint while paused updates at the next frame; the counts sum to 4,096. (FR-A16-420; SC-A16-402)

## Phase 6: Story 4 — presets

- [ ] T-A16-408 [US4] Create `Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresetStore.swift`:
  - one file per preset, `preset-<uuid>.json`, in `ExperienceStorage`; "≤ 24 files";
  - damaged, newer or refused files are reported and skipped;
  - save refused at 24 with "The library holds 24 experiments; delete one first."; delete.

  Add a Presets section to `SimulationControls.swift`: the bundled list (choosing one sends `sim.family` and
  `sim.preset`), the saved list (choosing one sends `sim.spec`), a name field with Save, and Delete. The factory passes
  `storage`. Tests in `ExperienceTests/PresetStoreTests.swift`, over a temporary storage root:
  - round trip across a store reload;
  - the cap, with the 25th save refused;
  - a damaged and a newer file reported and skipped;
  - loading a saved preset gives its spec.

  (FR-A16-430; SC-A16-403)

## Phase 7: Story 5 — capture

- [ ] T-A16-409 [US5] Create `Packages/ExperiencesCreative/SimulationLab/Experience/SimulationCapture.swift` (`TemporaryFolder(name: "a16-captures")`, 1024 × 1024 through a render closure, `StillImageEncoder.pngData`, one file replaced, a failure leaves no file and sets the message). Add Capture and a ShareLink to the controls through `@Environment(\.experienceStillRenderer)`: pause while capturing, then resume if it was running. The experience empties the folder when it opens. Tests in `ExperienceTests/CaptureTests.swift` with `session.renderStill`: two captures leave one 1024 × 1024 PNG; a throwing renderer leaves none with the message; the digest and the step count are unchanged. (FR-A16-440; SC-A16-404)

## Phase 8: Records and evidence

- [ ] T-A16-410 Contract `docs/apps/simulation-lab/visualcore-contract.json`: G-UI, G-LEGEND (the histogram assessed as app-local, research D2), G-PRESETS and G-CAPTURE closed by "A16-P04"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app simulation-lab --render`)
- [ ] T-A16-411 Simulation Lab tests on sim-27.2 (`--name sl-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SimulationLabCoreTests SimulationLabExperienceTests`; the slowest test under 10 s), documented API (`--name documented-api`), packages (`--name packages`), scripts (`--name scripts`) and copy claims (`--name copy-claims -- python3 scripts/check_copy_claims.py`) (SC-A16-401–405)
- [ ] T-A16-412 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a16.simulation-lab --runtime 27`) (FR-A16-450)

## Dependencies

- T-A16-401 runs first.
- T-A16-402 (an agent) and T-A16-403 (the lead) run together; T-A16-403 uses T-A16-402's `paint`.
- T-A16-404 through T-A16-409 follow in order, because they share the presenter and the controls.
- T-A16-408's store file and T-A16-409's capture file can be written by agents in parallel.
- T-A16-410 through T-A16-412 run last.

**Review checkpoints:** after T-A16-404 (the regression fixture) and after T-A16-409 (all four gaps). **MVP:** Story 1.
