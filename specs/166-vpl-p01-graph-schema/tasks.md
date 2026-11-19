# Tasks: Visual Programming Lab — Phase 01 Graph schema and type-checking fixtures

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/core.md](contracts/core.md), [quickstart.md](quickstart.md). Gate A23-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A23-P01 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/159-ss-p01-glsl-diagnostics/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A23-101 Baseline: cite the A23-P00 evidence (`.autonomy/checks/A23-P00.{app-build,no-change,experience-packages}.json`) — Verified 2026-11-18: 2026-11-18: A23-P00 evidence cited: .autonomy/checks/A23-P00.app-build.json, A23-P00.no-change.json and A23-P00.experience-packages.json, all exit 0; no Packages change since the A23-P00 record commit 96d7e526
  on the tree recorded at A23-P00 (`96d7e526`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [X] T-A23-102 Add two targets to `Packages/ExperiencesCreative/Package.swift` (lead); the package check still passes — Verified 2026-11-18: 2026-11-18: VisualProgrammingLabCore (VisualCoreParameters, VisualCorePersistence, VisualCoreExperience) and VisualProgrammingLabCoreTests (also VisualCoreRendering) in Packages/ExperiencesCreative/Package.swift; .autonomy/checks/A23-P01.experience-packages.json exit 0 (a pending core)
  (a pending core):
  - `VisualProgrammingLabCore` (path `VisualProgrammingLab/Core`, dependencies `VisualCoreParameters`,
    `VisualCorePersistence` and `VisualCoreExperience`);
  - `VisualProgrammingLabCoreTests` (path `VisualProgrammingLab/CoreTests`, dependencies `VisualProgrammingLabCore`,
    the same three products and `VisualCoreRendering`).

## Phase 2: Story 1 — a bounded graph document (P1) 🎯

- [X] T-A23-103 [P] [US1] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Core/{ValueType,NodeLibrary,VisualGraph}.swift` — Verified 2026-11-18: 2026-11-18: ValueType.swift (four value types, directions, port declarations), NodeLibrary.swift (the seven kinds' ports and ParameterDefinitions per clarification Q1; separate input(_:) and output(_:) because blur has an input and an output named image) and VisualGraph.swift (NodeID 1...9,999, CanvasPoint within 4,096, GraphNode, GraphEdge ordered by target, port, source, port; GraphLimits 32 and 64; the output is the node of kind output, not a stored field); .autonomy/checks/A23-P01.vpl-core-ios27.json exit 0 (70 tests in 7 suites on sim-27.2, slowest 0.047 s); written by an agent, retested
  per data-model.md and contracts/core.md, with `///` on every public declaration (FR-A23-101, 103):
  - `ValueType` (scalar, colour, texture, time), `PortDirection`, `PortDeclaration` (name "lowercase letters, 1…16",
    required for inputs only);
  - `NodeKind` with the seven kinds' ports and `ParameterDefinition`s exactly as the spec's clarification Q1 table;
  - `NodeID` "an integer 1…9,999", `CanvasPoint` "finite, each within −4,096…4,096", `GraphNode`, `GraphEdge`,
    `VisualGraph`, `GraphLimits` "`maxNodes` 32, `maxEdges` 64".
- [X] T-A23-104 [P] [US1] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Core/GraphDocument.swift` per — Verified 2026-11-18: 2026-11-18: GraphDocument.swift: kind a23.visual-graph, schema 1, at most 65,536 bytes, canonical JSON (sorted keys, nodes by id, edges sorted), body through MigrationChain(currentVersion: 1), refusals damaged, newer-version, too-large, not-finite (also NaN and Infinity strings on reading), out-of-range (ids incl. edge ends, positions, declared parameters), fingerprint by DigestBuilder(domain: a23.visual-graph); .autonomy/checks/A23-P01.vpl-core-ios27.json exit 0 (70 tests in 7 suites on sim-27.2, slowest 0.047 s); written by an agent, retested
  clarification Q3 (FR-A23-102): kind `a23.visual-graph`, schema 1, "≤ 65,536 bytes encoded, canonical JSON with
  sorted keys", the body through `MigrationChain(currentVersion: 1)`, refusal codes `damaged`, `newer-version`,
  `too-large`, `not-finite`, `out-of-range`, and `fingerprint(of:)` with `DigestBuilder(domain: "a23.visual-graph")`
  over the fields of Q3 in their order.
- [X] T-A23-105 [P] [US1] Write `Packages/ExperiencesCreative/VisualProgrammingLab/CoreTests/{LibraryTests,GraphModelTests,DocumentTests}.swift` — Verified 2026-11-18: 2026-11-18: LibraryTests (6, five over the 7 kinds), GraphModelTests (8) and DocumentTests (19): every kind's table, byte-identical round trips, every refusal code on reading and writing, each limit at and one past its bound, a stable fingerprint that changes with one value; .autonomy/checks/A23-P01.vpl-core-ios27.json exit 0 (70 tests in 7 suites on sim-27.2, slowest 0.047 s); written by an agent, retested
  (SC-A23-101):
  - every kind declares its ports and parameters, and every default lies in its range (US2 scenario 3);
  - graphs round-trip byte-identical with the same identities, connections and positions; one sample per refusal
    code; each limit at and one past its bound; the fingerprint is stable and changes with one value;
  - synthetic data only.

## Phase 3: Stories 2–4 — the checker (P1, P2)

- [ ] T-A23-106 [US2] [US3] [US4] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Core/GraphChecker.swift` per
  clarification Q4 and data-model "GraphIssue" and "CheckResult" (FR-A23-104–106): the five stages in order, stopping
  after a stage that refused; Kahn's order with the smallest ready identity first; the cycle path by the backward walk,
  reported forward from the connection whose source has the smallest identity; the nodes reaching the output.
- [ ] T-A23-107 [P] [US2] [US3] [US4] Write `Packages/ExperiencesCreative/VisualProgrammingLab/CoreTests/{GraphFixtures,TypeCheckTests,CycleTests,OutputTests}.swift`
  (SC-A23-102–104):
  - all 16 type pairs, exactly 4 connecting; unknown node and port, from an input, into an output, an input fed twice,
    a duplicate connection;
  - loops of 1, 2, 3 and 8 nodes and two separate loops, each refused with exactly the connections of the named loop;
    acyclic fixtures ordered with every node after its inputs, identical across 10 runs;
  - no output, two outputs, a disconnected output, an empty required input (each naming node and port); an empty
    optional input passes; a node not reaching the output is marked;
  - an undeclared parameter and a value outside its range are refused by name; a missing parameter takes its default.

## Phase 4: Story 5 — checking before graphics work (P2)

- [ ] T-A23-108 [US5] Write `Packages/ExperiencesCreative/VisualProgrammingLab/CoreTests/HostCountTests.swift` per
  clarification Q5 (SC-A23-105, FR-A23-107): a `RenderScene` on `RenderHost(scene:)` checks every fixture of
  `GraphFixtures` in `setup` and `render`, and `ResourceRegistry.stats` (`liveCount` for every kind, `totalBytes`) is
  the same before and after; the scene draws nothing and issues no GL call.

## Phase 5: Records and evidence

- [ ] T-A23-109 Core tests on sim-27.2, as a review checkpoint (SC-A23-106, FR-A23-107):
  - `--name vpl-core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
    ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing VisualProgrammingLabCoreTests`,
    with each test under 10 s;
  - the purity scan (`--name core-purity`, the quickstart's grep);
  - the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources
    Packages/ExperiencesCreative/VisualProgrammingLab`);
  - the isolation check (`--name isolation -- python3 scripts/check_app_isolation.py --experiences
    Packages/ExperiencesCreative/VisualProgrammingLab`).
- [ ] T-A23-110 Contract `docs/apps/visual-programming-lab/visualcore-contract.json`: G-MODEL and G-TYPES are closed by
  "A23-P01", and rows whose gaps are all closed become available with evidence (`--name contract -- python3
  scripts/check_app_contract.py --app visual-programming-lab --render`); list the core in
  `docs/apps/visual-programming-lab/README.md`
- [ ] T-A23-111 The packages, catalog and script tests and the app build:
  - `--name experience-packages`;
  - `--name catalog -- python3 scripts/build_catalog.py --check`;
  - `--name script-tests -- python3 scripts/test_scripts.py`;
  - `--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`.
- [ ] T-A23-112 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A23-P01; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

101 → 102 → {103/104/105, 106/107} → 108 → 109 → 110 → 111 → 112.
- **Separate files:** the model and the checker are separate files; the checker uses 103's types (agents work from
  contracts/core.md).
- **Host test:** 108 uses 107's fixtures.

## Parallel examples

- **Agent M:** 103, 104 and 105.
- **Agent C:** 106, 107 and 108.
- **Lead:** 102, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the model and file (103–105) with the cycle fixtures (106, 107).
- **Then:** the host-count proof (108) completes the phase.
- **Review checkpoint:** at 109.
- **Commits:** one per task.
