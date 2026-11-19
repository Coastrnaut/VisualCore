# Tasks: Visual Programming Lab — Phase 04 Save/load, examples and diagnostics

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/library.md](contracts/library.md), [quickstart.md](quickstart.md). Gate A23-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A23-P04 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/168-vpl-p03-graph-compiler/tasks.md`; the libraries of Shader Studio and Digital Zen Garden.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A23-401 Baseline: cite the A23-P03 evidence (`.autonomy/checks/A23-P03.{vpl-ios27-2,app-unit,verify-27}.json`) — Verified 2026-11-18: 2026-11-18: A23-P03 evidence cited: .autonomy/checks/A23-P03.vpl-ios27-2.json, A23-P03.app-unit.json and A23-P03.verify-27.json, all exit 0; no Packages change since the A23-P03 record commit 7508f7ed
  on the tree recorded at A23-P03 (`7508f7ed`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [X] T-A23-402 In `Packages/ExperiencesCreative/Package.swift` (lead), give `VisualProgrammingLabExperienceTests` the — Verified 2026-11-18: 2026-11-18: VisualProgrammingLabExperienceTests resources [.copy("Fixtures")] in Packages/ExperiencesCreative/Package.swift with ExperienceTests/Fixtures/graph-sample.json; .autonomy/checks/A23-P04.vpl-ios27.json exit 0 (162 core and 63 experience tests on sim-27.2, slowest 1.27 s)
  resources `[.copy("Fixtures")]`, with `ExperienceTests/Fixtures/` holding the stored samples

## Phase 2: Stories 1–2 — save, open and keep unreadable files (P1) 🎯

- [X] T-A23-403 [US1] [US2] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Experience/GraphLibrary.swift` per — Verified 2026-11-18: 2026-11-18: GraphLibrary.swift: graph-<n>.json (a23.saved-graph v1, body name, order and the embedded graph, at most 81,920 bytes) and library.json (a23.graph-library v1), 24 graphs, names trimmed 1...40 unique ignoring case, the three messages, unreadable files listed with their code and never deleted automatically, a newer index read only, atomic writes, a reader through an injectable MigrationChain; .autonomy/checks/A23-P04.vpl-ios27.json exit 0 (162 core and 63 experience tests on sim-27.2, slowest 1.27 s); written by an agent, retested
  clarification Q1 and data-model.md: `graph-<n>.json` ("envelope kind `a23.saved-graph`, version 1, body `{name,
  order, graph}`; at most 81,920 bytes"), `library.json` (kind `a23.graph-library`), "24 graphs", names "trimmed
  1…40, unique ignoring case", the three messages, unreadable files listed with their code and never deleted
  automatically, atomic writes through `storage.write`, a reader through `GraphDocument.migrations` with a test seam
  for another chain
- [X] T-A23-404 [US1] Wire the presenter and factory (`LabPresenter`, `VisualProgrammingLabExperience`): `library`, — Verified 2026-11-18: 2026-11-18: LabPresenter (library, save, open, rename, remove, examples, the replace confirmation by fingerprint baseline, restoreGraph), VisualProgrammingLabExperience (storage passed on; restore through shell.restore with a LabCore snapshot), LabControls (library button, examples menu, library-message, replace dialog) and LabLibraryView; .autonomy/checks/A23-P04.vpl-ios27.json exit 0 (162 core and 63 experience tests on sim-27.2, slowest 1.27 s); written by an agent, retested
  `save(name:)`, `open(file:)`, `rename(file:to:)`, `remove(file:)`, opening through a `restoreGraph` closure that calls
  `shell.restore(_:)` with a `LabCore` snapshot (no selection); the replace confirmation when the open graph differs
  from the last saved or opened one; `LabLibraryView` with the identifiers of contracts/library.md
- [X] T-A23-405 [US1] [US2] Write `ExperienceTests/{LibraryTests,LibraryRefusalTests,MigrationTests,StoredSampleTests}.swift` — Verified 2026-11-18: 2026-11-18: LibraryTests (5), LibraryRefusalTests (4), MigrationTests (3) and StoredSampleTests (2): round trips with equal fingerprints, caps at and one past, damaged, newer, oversized and out-of-range files listed, refused and kept, a full quota writes nothing, a newer index read only, a synthetic version-0 file migrating and opening, the committed sample written byte for byte by the encoder, the replace confirmation, one compile after opening; .autonomy/checks/A23-P04.vpl-ios27.json exit 0 (162 core and 63 experience tests on sim-27.2, slowest 1.27 s); written by an agent, one #expect macro error fixed by the lead, retested
  (SC-A23-401–403): save, open (equal fingerprint), rename and remove round trips with a temporary storage; the caps at
  and one past each bound; damaged, newer and oversized samples listed, refused and still present; a quota refusal
  writes nothing; a synthetic version-0 file migrates and opens; the committed schema-1 sample
  `Fixtures/graph-sample.json` reads back unchanged; opening over unsaved work asks first and declining changes nothing;
  an opened graph compiles once at the next frame

## Phase 3: Story 3 — examples (P2)

- [X] T-A23-406 [US3] Create `Experience/LabExamples.swift` (`clouds`, `soft-gradient`, `mixed-clouds` per — Verified 2026-11-18: 2026-11-18: LabExamples.swift (clouds, soft-gradient, mixed-clouds) with the examples menu through the restore path, ExampleTests (each passes the checker, compiles within budget and draws a non-flat inset), docs/apps/visual-programming-lab/licenses.md listed in the README; validate_docs PASS; .autonomy/checks/A23-P04.vpl-ios27.json exit 0 (162 core and 63 experience tests on sim-27.2, slowest 1.27 s); written by an agent, retested
  clarification Q4) with an "Examples" menu (`example-<id>`) through the same restore path, and
  `ExperienceTests/ExampleTests.swift` (SC-A23-404): each passes the checker, compiles within the budget and draws a
  non-flat inset; write `docs/apps/visual-programming-lab/licenses.md` and list it in the README

## Phase 4: Story 4 — diagnostics on nodes (P2)

- [X] T-A23-407 [US4] Create `Core/GraphDiagnostics.swift` and `CoreTests/DiagnosticsTests.swift` per clarification Q5 — Verified 2026-11-18: 2026-11-18: Core/GraphDiagnostics.swift (byNode and sentences, per clarification Q5) and CoreTests/DiagnosticsTests.swift (10: every fixture marks exactly the nodes the checker names, accepted graphs mark none, loops mark each node of the named loop); .autonomy/checks/A23-P04.vpl-ios27.json exit 0 (162 core and 63 experience tests on sim-27.2, slowest 1.27 s); written by an agent, retested
  (SC-A23-405): exactly the nodes the checker names are marked, with their sentences; a valid graph marks none
- [X] T-A23-408 [US4] Show the marks in `Experience/{CanvasOverlay,LabControls}.swift` (a dashed outline and a "!" badge, — Verified 2026-11-18: 2026-11-18: the mirror holds GraphDiagnostics.byNode after each core change; CanvasOverlay draws a dashed red outline and a ! badge (node-diagnostic-<id>, spoken) and adds the sentences to the node's label; LabControls lists the sentences under the node (node-diagnostic-row-<id>); DiagnosticsDisplayTests (the starter marks nothing, a disconnected Output and a Mix missing b are marked, reconnecting clears); .autonomy/checks/A23-P04.vpl-ios27.json exit 0 (162 core and 63 experience tests on sim-27.2, slowest 1.27 s); written by the lead
  `node-diagnostic-<id>`, spoken; the sentences under the node in the list form) and write
  `ExperienceTests/DiagnosticsDisplayTests.swift` (the presenter's mirror holds the marks for each invalid fixture)

## Phase 5: Evidence

- [X] T-A23-409 Review checkpoint: `--name vpl-ios27` (both test targets, each test under 10 s, SC-A23-406), the — Verified 2026-11-18: 2026-11-18: review checkpoint: .autonomy/checks/A23-P04.vpl-ios27.json exit 0 (162 core and 63 experience tests on sim-27.2, slowest 1.27 s); A23-P04.documented-api.json, A23-P04.isolation.json and A23-P04.core-purity.json exit 0; the manifest test passes without regeneration
  documented API, isolation and core purity; regenerate `scenario-manifest.json` if the manifest test asks for it
- [X] T-A23-410 Contract: G-LIBRARY closed by "A23-P04", rows whose gaps are all closed available (`--name contract`) — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P04.contract.json exit 0 (G-LIBRARY closed by A23-P04; M05, M11 and M19 available with their notes)
- [ ] T-A23-411 The catalog, packages and script tests, `xcodegen generate`, the app build and unit tests (`--name
  app-unit`) and the runner (`--name verify-27`)
- [ ] T-A23-412 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A23-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

401 → 402 → 403 → 404 → {405, 406} → 407 → 408 → 409 → 410 → 411 → 412; 407 can start with 403 (core only).

## Parallel examples

- **Agent B:** 403–406. **Agent D:** 407–408 (408 after B's presenter wiring lands; D edits CanvasOverlay and
  LabControls only for the marks, B edits them only for the library view entry and examples menu — B goes first).
- **Lead:** 402, licenses.md, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the library with its round trip and refusals (403–405).
- **Then:** examples (406) and node diagnostics (407, 408).
- **Review checkpoint:** at 409.
- **Commits:** one per task.
