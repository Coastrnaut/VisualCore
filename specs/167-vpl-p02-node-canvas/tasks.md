# Tasks: Visual Programming Lab — Phase 02 Node canvas and connections

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A23-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A23-P02 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/160-ss-p02-compile-preview/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A23-201 Baseline: cite the A23-P01 evidence (`.autonomy/checks/A23-P01.{vpl-core-ios27,app-build,experience-packages}.json`) — Verified 2026-11-18: 2026-11-18: A23-P01 evidence cited: .autonomy/checks/A23-P01.vpl-core-ios27.json, A23-P01.app-build.json and A23-P01.experience-packages.json, all exit 0; no Packages change since the A23-P01 record commit bcaa472a
  on the tree recorded at A23-P01 (`bcaa472a`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [X] T-A23-202 In `Packages/ExperiencesCreative/Package.swift` (lead): add `VisualCoreMath` to the core and its tests; — Verified 2026-11-18: 2026-11-18: VisualCoreMath added to VisualProgrammingLabCore and its tests; VisualProgrammingLabExperience (core, Parameters, Experience, Persistence, Math, Scenes, Rendering, ExperienceHost, UI) and VisualProgrammingLabExperienceTests targets and the VisualProgrammingLabExperience product in Packages/ExperiencesCreative/Package.swift; .autonomy/checks/A23-P02.vpl-ios27.json exit 0 (125 core and 27 experience tests on sim-27.2, slowest 0.199 s)
  add the targets `VisualProgrammingLabExperience` (path `VisualProgrammingLab/Experience`) and
  `VisualProgrammingLabExperienceTests` (path `VisualProgrammingLab/ExperienceTests`) with the products of plan.md, and
  the `VisualProgrammingLabExperience` library product

## Phase 2: Core additions (blocking)

- [X] T-A23-203 [P] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Core/{GraphEditor,EditMessages}.swift` with — Verified 2026-11-18: 2026-11-18: GraphEditor.swift (add with the smallest unused identity, 32-node and one-output refusals; move and add clamped to 4,096; remove with its connections; connect refusing unknown nodes and ports, mismatched types, a fed input, a 65th connection (tooManyEdges, a23.too-many-edges, added by the lead) and a checker cycle, accepting incomplete graphs; disconnect) and EditMessages.swift (sentences, status, titles, spoken labels of nodes, ports and connections); EditorTests (22) and EditMessagesTests (11); .autonomy/checks/A23-P02.vpl-ios27.json exit 0 (125 core and 27 experience tests on sim-27.2, slowest 0.199 s); written by an agent, the edge limit added by the lead, retested
  `CoreTests/{EditorTests,EditMessagesTests}.swift` per data-model.md and clarification Q1 (FR-A23-202, 203): the new
  node takes "the smallest unused identity"; refused "at 32 nodes" and "for a second output"; remove takes its
  connections; connect refuses any connection-stage issue or a cycle of `GraphChecker` and accepts an incomplete graph;
  positions "clamped to ±4,096"; one sentence per refusal and per checker status, and the spoken labels of a node, a port
  and a connection ("Noise 2 image → Output 1 image") (SC-A23-202, FR-A23-205)
- [X] T-A23-204 [P] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Core/{CanvasLayout,CanvasView}.swift` with — Verified 2026-11-18: 2026-11-18: CanvasLayout.swift (168-point boxes, 32-point title, 36-point rows, 44-point port targets in canvas points, wire handles max(40, |dx|/2), hit order port, topmost node, empty) and CanvasView.swift (PlaneViewport with y flipped, zoom 0.5...2 with the anchor kept, centre within 4,096); CanvasLayoutTests (11) and CanvasViewTests (9); .autonomy/checks/A23-P02.vpl-ios27.json exit 0 (125 core and 27 experience tests on sim-27.2, slowest 0.199 s); written by an agent, retested
  `CoreTests/{CanvasLayoutTests,CanvasViewTests}.swift` per data-model.md and clarifications Q2–Q3 (FR-A23-204, 205):
  box "168 points wide, a 32-point title row and one 36-point row per port row"; "44 × 44-point" targets scaled by the
  zoom; wire handles "max(40, |dx| / 2)"; hit order port, topmost node, empty; zoom "0.5…2 (1 by default)", centre
  "clamped to ±4,096" (SC-A23-203, 204)

## Phase 3: Stories 1–2 — build a graph; wrong connections refused (P1) 🎯

- [X] T-A23-205 [US1] [US2] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Experience/Adapter/LabCore.swift` per — Verified 2026-11-18: 2026-11-18: Adapter/LabCore.swift: snapshot schema 1 (graph and selection), digest a23.visual-programming-lab.v1 over the graph's fingerprint only, the six controls with their ranges, nine rule ids (with a23.too-many-edges), restore refusals, the starter graph Noise 1 into Output 2, outcome graph-ready when the checker accepts; .autonomy/checks/A23-P02.vpl-ios27.json exit 0 (125 core and 27 experience tests on sim-27.2, slowest 0.199 s); written by an agent, retested
  clarification Q1: "snapshot schema 1, digest `a23.visual-programming-lab.v1` over the graph", selection in the
  snapshot only, the six actions with their ranges, the eight rule ids, the starter graph "Noise (id 1, at 40, 80) into
  Output (id 2, at 320, 80)", restore refusals for damaged or out-of-range snapshots; `///` everywhere
- [X] T-A23-206 [US1] [US3] [US5] Create `Experience/{GridScene,LabPresenter,CanvasOverlay,LabControls,VisualProgrammingLabExperience}.swift` — Verified 2026-11-18: 2026-11-18: GridScene (FullScreenShaderScene grid, minor 32 and major 160 canvas points, uniforms zoom, panX, panY, width, height), LabPresenter (30 frames per second, level-0, touch mapping of clarification Q3, view state, feedback, rubber wire, cancelPointers), CanvasOverlay (wires, boxes, port shapes by type, selection, identifiers and labels), LabControls (add menu, remove, move buttons, list form with input pickers, status, feedback) and VisualProgrammingLabExperience; .autonomy/checks/A23-P02.isolation.json exit 0; .autonomy/checks/A23-P02.vpl-ios27.json exit 0 (125 core and 27 experience tests on sim-27.2, slowest 0.199 s); written by an agent, retested
  per clarifications Q3–Q4 and contracts/experience.md (FR-A23-201–206): the grid through `FullScreenShaderScene`
  ("minor lines every 32 canvas points, major every 160", uniforms `zoom` and `pan`), 30 frames per second, tier
  `level-0`; the touch mapping; the overlay and controls with the identifiers of the contract and spoken labels; no GL
  call of the experience
- [ ] T-A23-207 [US1] [US2] [US4] Write `ExperienceTests/{LabTestSupport,LabCoreTests,TouchTests}.swift`
  (SC-A23-201–204): the journey graph built by actions and by simulated touches gives the same fingerprint; every
  refusal fixture leaves the digest unchanged and sets its sentence; zoom and pan never change the digest; the
  starter graph's port targets are at least 44 points; a drag between two inputs sends nothing and shows "Connect an
  output to an input."; `cancelPointers` mid-drag leaves the graph as of the last move and no rubber wire

## Phase 4: Story 5 — the canvas survives interruptions (P2)

- [ ] T-A23-208 [US5] Write `ExperienceTests/{CanvasDrawTests,RebuildTests}.swift` (SC-A23-205): the picture drawn off
  screen changes with pan and zoom; 10 `recreateContext` calls and a resize there and back give a byte-identical
  picture with `leaked` 0

## Phase 5: Registration and evidence

- [ ] T-A23-209 Register the candidate (FR-A23-207):
  - a `Catalog/registrations.json` entry for a23: capabilities of at most 40 characters each, quality_tiers
    ["level-0"], a palette, manifest `Packages/ExperiencesCreative/VisualProgrammingLab/scenario-manifest.json`,
    permissions []; then `python3 scripts/build_catalog.py`;
  - in `Apps/VisualCore/App/ExperienceRegistry.swift`, the candidate `visualProgrammingLab` (no examples: schema 1);
  - the `project.yml` product;
  - in `Apps/VisualCore/Tests/Unit/AppModelTests.swift`, the synthetic candidate id moves to
    `a24.graphics-benchmark-lab`;
  - the candidate lists in the app and script tests.
- [ ] T-A23-210 Write `Experience/Adapter/LabManifest.swift` (nine standard scenarios, plus fixtures for the starter
  graph, the journey graph and a refused connection) and `ExperienceTests/LabManifestTests.swift`; generate
  `scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`
- [ ] T-A23-211 Review checkpoint:
  - `--name vpl-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
    ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing VisualProgrammingLabCoreTests
    VisualProgrammingLabExperienceTests`, each test under 10 s (SC-A23-206);
  - the documented API, the isolation check and the core purity scan.
- [ ] T-A23-212 Contract: G-CANVAS is closed by "A23-P02", and rows whose gaps are all closed become available with
  evidence (`--name contract`)
- [ ] T-A23-213 The catalog, app and runner checks, with the packages and script tests:
  - `--name catalog`; `--name experience-packages`; `--name script-tests`;
  - `xcodegen generate --spec project.yml`, then `--name app-unit -- python3 scripts/release_check.py --only
    app-build-for-testing-ios27 app-unit-ios27`;
  - `--name verify-27 -- python3 scripts/verify_experiences.py --only a23.visual-programming-lab --runtime 27`.
- [ ] T-A23-214 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A23-P02; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

201 → 202 → {203, 204} → 205 → 206 → {207, 208} → 209 → 210 → 211 → 212 → 213 → 214.
- **Core first:** the experience uses 203's editor and messages and 204's layout and view (agents work from
  data-model.md).

## Parallel examples

- **Agent E:** 203. **Agent L:** 204. **Agent X:** 205–208 and 210.
- **Lead:** 202, 209, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the editor and layout (203, 204) with the core adapter and touch tests (205, 207).
- **Then:** the drawing and rebuild proofs (206, 208) and the registration (209, 210).
- **Review checkpoint:** at 211.
- **Commits:** one per task.
