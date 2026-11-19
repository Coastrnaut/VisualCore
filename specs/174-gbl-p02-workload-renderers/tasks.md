# Tasks: Graphics Benchmark Lab — Phase 02 Three deterministic workload renderers

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A24-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A24-P02 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/167-vpl-p02-node-canvas/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A24-201 Baseline: cite the A24-P01 evidence (`.autonomy/checks/A24-P01.{gbl-core-ios27,app-build,experience-packages}.json`) — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P01.{gbl-core-ios27,app-build,experience-packages}.json exit 0 at A24-P01; Packages unchanged since ee5a5f3e
  on the tree recorded at A24-P01 (`ee5a5f3e`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [X] T-A24-202 In `Packages/ExperiencesCreative/Package.swift` (lead): add `VisualCoreMath` and `VisualCoreSimulation` — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P02.gbl-ios27.json exit 0 (50 core and 33 experience tests on sim-27.2); core + VisualCoreMath, VisualCoreSimulation; GraphicsBenchmarkLabExperience(+Tests) with VisualCoreScenes, library product
  to the core and its tests; add `GraphicsBenchmarkLabExperience` (path `GraphicsBenchmarkLab/Experience`) with its
  library product and `GraphicsBenchmarkLabExperienceTests`, with the dependencies of contracts/experience.md

## Phase 2: Core (pure)

- [X] T-A24-203 [P] Create `Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/{RunTimeline,ParticleField}.swift` — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P02.gbl-ios27.json exit 0 (50 core and 33 experience tests on sim-27.2); RunTimeline (half-open phase bounds) and ParticleField (splitmix64, wrapped)
  per clarifications Q1–Q2 and data-model.md, with `///` everywhere: `RunTimeline(plan:start:)` with `phase(at:)`
  ("warm-up while t − start < warm-up; measure while < warm-up + measure; cool-down while < total; then nil") and
  `endTime`; `ParticleField` (a hash for the start position, a fixed velocity, wrapped into the view, pure in index and
  frame)
- [ ] T-A24-204 [P] Write `CoreTests/{RunTimelineTests,ParticleFieldTests}.swift` (SC-A24-202): the spec's US2 frame
  times give the expected phases, the boundaries at exactly 3, 13 and 18 s; the particle field is identical for the
  same index and frame and stays inside the view

## Phase 3: Story 1 — three deterministic workloads (P1) 🎯

- [ ] T-A24-205 [US1] Create `Experience/Workloads.swift` per clarification Q1 (FR-A24-201, 202): the three workloads
  over `FieldPass`, render targets and `ParticleRenderer`, built from a validated `BenchmarkCase`, refusing a case
  over `ResourceRegistry.maxTextureSize` before allocation; setup, draw(frame n), resize and release; no GL call of
  their own
- [ ] T-A24-206 [US1] Write `ExperienceTests/{BenchTestSupport,WorkloadDrawTests}.swift` (SC-A24-201): for each case,
  frames 0 and 60 drawn off screen are not blank ("luma spans at least 16 of 255"), differ from each other, and are
  byte-identical across two hosts; a case over the limit allocates nothing

## Phase 4: Stories 2 and 3 — the run (P1)

- [ ] T-A24-207 [US2] [US3] Create `Experience/Adapter/BenchCore.swift` (clarification Q3) and
  `Experience/{RunRecorder,BenchPresenter,GBLControls,GraphicsBenchmarkLabExperience}.swift` (clarifications Q2, Q4;
  contracts/experience.md) (FR-A24-203–205): "snapshot schema 1, digest `a24.graphics-benchmark-lab.v1`", the three
  actions, the recorder (interval from consecutive frame times, absent for the first; `cpuMs` from `ContinuousClock`
  around the workload draw; `gpuMs` absent), the status words and summary text, inline case buttons, 60 frames per
  second, tier `level-0`
- [ ] T-A24-208 [US2] [US3] Write `ExperienceTests/{BenchCoreTests,RecorderTests}.swift` (SC-A24-202, 203): actions and
  refusals; a run fed synthetic frame times passes warm-up, measure and cool-down and finishes with a summary counting
  only measured frames; every sample has `gpuMs` nil and the encoded run file holds no GPU value; the summary has no
  GPU distribution and the flag "gpu-time-not-available"; the status text names it; stop mid-run gives "Stopped";
  choosing another case mid-run ends the run as "Stopped" before the new case is drawn; closing the session mid-run
  ends it as "Interrupted"

## Phase 5: Story 4 — interruptions (P2)

- [ ] T-A24-209 [US4] Write `ExperienceTests/RebuildTests.swift` (SC-A24-204): 10 `recreateContext` calls and a resize
  there and back give a byte-identical picture of the same frame with `leaked` 0; a rebuild during a run ends it as
  interrupted with its samples kept

## Phase 6: Registration and evidence

- [ ] T-A24-210 Register the candidate (FR-A24-207):
  - a `Catalog/registrations.json` entry for a24 (capabilities of at most 40 characters each, a summary of at most 300
    characters keeping the words CatalogSearchTests searches for, quality_tiers ["level-0"], a palette, manifest
    `Packages/ExperiencesCreative/GraphicsBenchmarkLab/scenario-manifest.json`, permissions []); then
    `python3 scripts/build_catalog.py`, and `swift test --package-path Packages/VisualCore --filter CatalogSearchTests`;
  - in `Apps/VisualCore/App/ExperienceRegistry.swift`, the candidate `graphicsBenchmarkLab`;
  - the `project.yml` product;
  - in `Apps/VisualCore/Tests/Unit/AppModelTests.swift`, the synthetic candidate id moves to `a25.effects-composer`;
  - the candidate lists in the app and script tests.
- [ ] T-A24-211 Write `Experience/Adapter/GBLManifest.swift` (nine standard scenarios plus a fixture per case, and a
  frame probe chosen where the opening picture's colour class holds at every time) and
  `ExperienceTests/GBLManifestTests.swift`; generate `scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1
  TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`
- [ ] T-A24-212 Review checkpoint:
  - `--name gbl-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
    ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing GraphicsBenchmarkLabCoreTests
    GraphicsBenchmarkLabExperienceTests`, each test under 10 s (SC-A24-206);
  - the documented API, the isolation check and the core purity scan.
- [ ] T-A24-213 Contract: G-SCENES is closed by "A24-P02", and rows whose gaps are all closed become available with
  evidence (`--name contract`)
- [ ] T-A24-214 The catalog, app and runner checks, with the packages and script tests:
  - `--name catalog`; `--name experience-packages`; `--name script-tests`;
  - `xcodegen generate --spec project.yml`, then `--name app-unit -- python3 scripts/release_check.py --only
    app-build-for-testing-ios27 app-unit-ios27`;
  - `--name verify-27 -- python3 scripts/verify_experiences.py --only a24.graphics-benchmark-lab --runtime 27`.
- [ ] T-A24-215 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A24-P02; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

201 → 202 → {203, 205, 207} (separate files); 203 → 204; 205 → 206, 209; 207 → 208; {204, 206, 208, 209} → 210 →
211 → 212 → 213 → 214 → 215.

## Parallel examples

- **Agent C:** 203, 204. **Agent W:** 205, 206, 209. **Agent E:** 207, 208, 211 (manifest Swift and its test).
- **Lead:** 201, 202, 210, the manifest generation, runs, contract and commits.

## Implementation strategy

- **MVP:** the workloads and the run (205, 207).
- **Review checkpoint:** at 212.
- **Commits:** one per task.
