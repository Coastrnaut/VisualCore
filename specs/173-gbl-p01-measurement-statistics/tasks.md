# Tasks: Graphics Benchmark Lab — Phase 01 Measurement methodology and fixture statistics

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/core.md](contracts/core.md), [quickstart.md](quickstart.md). Gate A24-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A24-P01 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/166-vpl-p01-graph-schema/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A24-101 Baseline: cite the A24-P00 evidence (`.autonomy/checks/A24-P00.{app-build,no-change-2,experience-packages}.json`) — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P00.{app-build,no-change-2,experience-packages}.json exit 0 at A24-P00; Packages unchanged since 03e0c255
  on the tree recorded at A24-P00 (`03e0c255`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [X] T-A24-102 Add two targets to `Packages/ExperiencesCreative/Package.swift` (lead); the package check still passes — Verified 2026-11-19: 2026-11-19: GraphicsBenchmarkLabCore and GraphicsBenchmarkLabCoreTests added; .autonomy/checks/A24-P01.experience-packages.json exit 0 (a pending core)
  (a pending core):
  - `GraphicsBenchmarkLabCore` (path `GraphicsBenchmarkLab/Core`, dependencies `VisualCoreExperience` and
    `VisualCorePersistence`);
  - `GraphicsBenchmarkLabCoreTests` (path `GraphicsBenchmarkLab/CoreTests`, dependencies `GraphicsBenchmarkLabCore`,
    the same two products and `VisualCoreRendering`; resources `.copy("Fixtures")`).

## Phase 2: Story 1 — a fixed, bounded case (P1) 🎯

- [X] T-A24-103 [P] [US1] Create `Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/BenchmarkCase.swift` per — Verified 2026-11-19: 2026-11-19: Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/BenchmarkCase.swift (cases, caps, fingerprint domain a24.benchmark-case.v1, three built-ins); .autonomy/checks/A24-P01.gbl-core-ios27.json exit 0
  data-model.md and contracts/core.md, with `///` on every public declaration (FR-A24-101, 102): `Workload`,
  `WorkloadConfig`, `RunPlan`, `CaseLimits` ("layers 1…64; textureSize 64…1,024, a power of two; iterations 1…1,024;
  particles 1…100,000; resolutionScale 0.25…1.0; warmUpSeconds 1…30; measureSeconds 1…60; coolDownSeconds 0…120"),
  `CaseError`, `BenchmarkCase` with `validate()`, `fingerprint()` (`DigestBuilder(domain: "a24.benchmark-case.v1")`)
  and the three built-ins of clarification Q1.
- [X] T-A24-104 [P] [US1] [US3] Create `Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/FrameSample.swift` — Verified 2026-11-19: 2026-11-19: Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/FrameSample.swift (phases, sample caps, SampleSet.validate); gbl-core-ios27 exit 0
  (FR-A24-102): `RunPhase`, `FrameSample` ("every duration finite and within 0…1,000 ms; intervalMs absent only for
  the run's first frame"), `SampleLimits` ("maxSamples 20,000"), `SampleError`, `SampleSet.validate` (frame indices
  strictly increasing, phases never going back).
- [X] T-A24-105 [P] [US1] [US3] Write `Packages/ExperiencesCreative/GraphicsBenchmarkLab/CoreTests/{CaseTests,SampleTests}.swift` — Verified 2026-11-19: 2026-11-19: CaseTests and SampleTests pass in .autonomy/checks/A24-P01.gbl-core-ios27.json (40 tests, 0.088 s)
  (SC-A24-102, 103): the built-ins validate with three distinct stable fingerprints; one changed value changes the
  fingerprint; each cap at and one past its bound; a field of the wrong workload refused; NaN, infinity, negative and
  over-1,000 ms durations refused naming frame and field; out-of-order indices and phases; 20,001 samples.

## Phase 3: Stories 2 and 4 — statistics and flags (P1, P2)

- [X] T-A24-106 [US2] [US4] Create `Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/Statistics.swift` per — Verified 2026-11-19: 2026-11-19: Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/Statistics.swift (nearest rank, minimum counts 1/20/100, Distribution, QualityFlag, Summary.make); gbl-core-ios27 exit 0
  clarification Q2 (FR-A24-103, 104): `Percentiles.nearestRank` ("rank = (p·n + 99) / 100, the rank-th smallest";
  minimum counts p50 1, p95 20, p99 100), `Distribution`, `QualityFlag`, `Summary` and `Summary.make` (validates the
  set first; warm-up and cool-down left out and counted; a measured sample without an interval not counted in the
  interval distribution; a GPU distribution only when every measured sample has a GPU time).
- [X] T-A24-107 [P] [US2] [US4] Write the fixtures and their tests (FR-A24-106, SC-A24-101): — Verified 2026-11-19: 2026-11-19: 14 committed fixtures and the 20,000-sample rule set; FixtureTests and StatisticsTests pass in gbl-core-ios27 exit 0
  - `CoreTests/Fixtures/*.json`: each a sample set with its expected summary, computed by hand: 1 … 100 ms shuffled;
    empty; one sample; all equal; ties at the p95 boundary; 19, 20, 99 and 100 samples; warm-up only; with warm-up
    and cool-down; dropped frames; without and with GPU times; 20,000 samples generated by a rule stated in the
    fixture (interval = 1 + (k mod 1,000) / 100 ms for k = 0 … 19,999), whose percentiles follow from the rule;
  - `CoreTests/{FixtureSupport,FixtureTests,StatisticsTests}.swift`: every fixture matches exactly; the result of a
    shuffled set equals the sorted one; percentiles of small sets by the rule.

## Phase 4: Run file (P1)

- [ ] T-A24-108 [US3] Create `Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/BenchmarkRun.swift` per
  clarification Q4 (FR-A24-105): `RunState`, `BenchmarkRun`, `RunDocument` (kind `a24.benchmark-run`, version 1,
  "≤ 2,097,152 bytes", sorted keys, `MigrationChain(currentVersion: 1)`), `RunRefusal` with its codes; the reader
  recomputes the summary and refuses a mismatch as `damaged`.
- [ ] T-A24-109 [P] [US3] Write `CoreTests/RunDocumentTests.swift` (SC-A24-104): a run round-trips byte-identical; one
  sample per refusal code (damaged, newer-version, too-large, not-finite, out-of-range with its field, out-of-order,
  too-many-samples, a tampered summary).

## Phase 5: Story 5 — apart from graphics work (P2)

- [ ] T-A24-110 [US5] Write `CoreTests/HostCountTests.swift` per clarification Q5 (SC-A24-105, FR-A24-107): a
  `RenderScene` on `RenderHost(scene:)` validates the cases, summarises every fixture and encodes a run in `setup` and
  `render`, and `ResourceRegistry.stats` (`liveCount` for every kind, `totalBytes`) is the same before and after.

## Phase 6: Records and evidence

- [ ] T-A24-111 Core tests on sim-27.2, as a review checkpoint (SC-A24-106, FR-A24-108):
  - `--name gbl-core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
    ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing GraphicsBenchmarkLabCoreTests`,
    with each test under 10 s;
  - the purity scan (`--name core-purity`, the quickstart's grep);
  - the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources
    Packages/ExperiencesCreative/GraphicsBenchmarkLab`);
  - the isolation check (`--name isolation -- python3 scripts/check_app_isolation.py --experiences
    Packages/ExperiencesCreative/GraphicsBenchmarkLab`).
- [ ] T-A24-112 Contract `docs/apps/graphics-benchmark-lab/visualcore-contract.json`: G-MODEL and G-STATS are closed
  by "A24-P01", and rows whose gaps are all closed become available with evidence (`--name contract -- python3
  scripts/check_app_contract.py --app graphics-benchmark-lab --render`); list the core in
  `docs/apps/graphics-benchmark-lab/README.md`
- [ ] T-A24-113 The packages, catalog and script tests and the app build:
  - `--name experience-packages`;
  - `--name catalog -- python3 scripts/build_catalog.py --check`;
  - `--name script-tests -- python3 scripts/test_scripts.py`;
  - `--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`.
- [ ] T-A24-114 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A24-P01; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

101 → 102 → {103, 104, 106, 108} (one shared contract; separate files); 103/104 → 105; 106 → 107; 108 → 109;
{105, 107, 109} → 110 → 111 → 112 → 113 → 114.

## Parallel examples

- **Agent M:** 103, 104, 105, 108, 109 (models, run file and their tests).
- **Agent S:** 106, 107, 110 (statistics, fixtures, host test), against contracts/core.md.
- **Lead:** 101, 102, the runs, the contract, the README and the commits.

## Implementation strategy

- **MVP:** cases and statistics (103, 106, 107).
- **Then:** samples, the run file and the host proof.
- **Review checkpoint:** at 111.
- **Commits:** one per task.
