# Tasks: Visual Programming Lab — Phase 03 Bounded graph compiler and preview

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/preview.md](contracts/preview.md), [quickstart.md](quickstart.md). Gate A23-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A23-P03 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/167-vpl-p02-node-canvas/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A23-301 Baseline: cite the A23-P02 evidence (`.autonomy/checks/A23-P02.{vpl-ios27-3,app-unit-2,verify-27-2}.json`) — Verified 2026-11-18: 2026-11-18: A23-P02 evidence cited: .autonomy/checks/A23-P02.vpl-ios27-3.json, A23-P02.app-unit-2.json and A23-P02.verify-27-2.json, all exit 0; no Packages change since the A23-P02 record commit 24ffe464
  on the tree recorded at A23-P02 (`24ffe464`), whose Packages are unchanged since (owner ruling of 2026-11-14)

## Phase 2: Core compiler (blocking)

- [X] T-A23-302 [P] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Core/{GraphCompiler,PreviewValues}.swift` with — Verified 2026-11-18: 2026-11-18: GraphCompiler.swift (passes for texture nodes reaching the Output in the checker's order, Blur as blur-h and blur-v, Time and Constant as values, lowest-free-slot assignment freed after the last read, 256 x 256 x 4 bytes per slot, the 6-slot limit with its sentence, invalid graphs refused with the checker's status, content keys without positions and changed(from:to:)) and PreviewValues.swift; CompilerTests (10), SlotTests (6), ContentKeyTests (8), PreviewValuesTests (3); .autonomy/checks/A23-P03.vpl-ios27.json and A23-P03.vpl-ios27-2.json exit 0 (152 core and 46 experience tests on sim-27.2, slowest 0.93 s); written by an agent, retested
  `CoreTests/{CompilerTests,SlotTests,ContentKeyTests,PreviewValuesTests}.swift` per data-model.md and clarifications
  Q1–Q3 (FR-A23-301, 303, 304, 305): passes for texture nodes reaching the Output in the checker's order (Blur two),
  values for Time and Constant; "lowest free slot, freed after the last read"; "256 × 256 × 4 bytes" per slot and a
  limit of "6 slots" refused with "This graph needs N textures; the preview allows 6."; an invalid graph refused with
  the checker's status; content keys and `changed(from:to:)` (SC-A23-302–304)

## Phase 3: Stories 1–3 — picture, invalid state, budget (P1) 🎯

- [X] T-A23-303 [US1] Create `Packages/ExperiencesCreative/VisualProgrammingLab/Experience/{Operators,PreviewPipeline}.swift` — Verified 2026-11-18: 2026-11-18: Operators.swift (noise with vc_fbm, gradient, mix, a normalised Gaussian blur of 2r + 1 taps for both directions, output copy) and PreviewPipeline.swift (one FieldPass per program per context, rgba8 256 x 256 slots allocated only after the budget passes, the passes and the bottom-left inset of a third of the shorter side, PreviewState, compileCount, release on teardown); .autonomy/checks/A23-P03.vpl-ios27.json and A23-P03.vpl-ios27-2.json exit 0 (152 core and 46 experience tests on sim-27.2, slowest 0.93 s); written by an agent, retested
  per clarifications Q4–Q5 and contracts/preview.md: the six operator texts; programs built once per context through
  `FieldPass`; slots through `makeRenderTarget` (rgba8 256 × 256) only after the budget passes; the passes and the
  bottom-left inset; `PreviewState`; `compileCount`; release on teardown
- [X] T-A23-304 [US1] [US2] [US3] Modify `Experience/{LabPresenter,CanvasOverlay,LabControls}.swift`: compile at the next — Verified 2026-11-18: 2026-11-18: LabPresenter (pipeline, previewVisible, previewState; at most one compile at the next draw when the graph changed; restore on setup, release on teardown), GridScene as a full-framebuffer FieldPass (same fragment and floats), CanvasOverlay (the preview frame, Preview label and preview-message), LabControls (preview-toggle), LabTestSupport helpers; .autonomy/checks/A23-P03.vpl-ios27.json and A23-P03.vpl-ios27-2.json exit 0 (152 core and 46 experience tests on sim-27.2, slowest 0.93 s); .autonomy/checks/A23-P03.isolation.json exit 0; written by an agent, retested
  `draw` when the fingerprint changed (once per frame), draw grid then passes then inset; the grid becomes a
  `FieldPass` drawn to `.framebuffer(name: context.framebuffer, width: context.pixelWidth, height: context.pixelHeight)`
  (same fragment and parameters), because `FieldPass` sets the full viewport while `FullScreenShaderScene` sets none
  and the host does not reset it, so the inset's viewport would otherwise carry into the next frame; the inset frame
  (`preview`), its message (`preview-message`) and the switch (`preview-toggle`)
- [X] T-A23-305 [US1] Write `ExperienceTests/OperatorPixelTests.swift` (SC-A23-301): gradient, mix (0, 0.5, 1) and flat — Verified 2026-11-18: 2026-11-18: OperatorPixelTests (6, mix over 3 amounts): gradient, mix and a flat colour within 2 of 255 at the read pixel centres, noise deterministic and scale-dependent, blur of a ramp equal to it beyond its radius from the edges, output a copy of its slot; .autonomy/checks/A23-P03.vpl-ios27.json and A23-P03.vpl-ios27-2.json exit 0 (152 core and 46 experience tests on sim-27.2, slowest 0.93 s); written by an agent, retested
  colour within 2 of 255 at the read pixel centres; noise deterministic and scale-dependent; blur of a ramp equal to
  it farther than its radius from the edges; output a copy
- [X] T-A23-306 [US2] [US3] Write `ExperienceTests/{PreviewStateTests,BudgetTests}.swift` (SC-A23-302, 303): every — Verified 2026-11-18: 2026-11-18: PreviewStateTests (4: every invalid fixture shows its message and draws no pass, reconnecting restores the picture, the hidden preview draws no pass and keeps the digest, a failing operator shows its failure while the canvas keeps drawing) and BudgetTests (3: 6 slots compile with bytes equal to the host's, 7 refused with the registry unchanged, a 5-pass chain in at most 2 slots); .autonomy/checks/A23-P03.vpl-ios27.json and A23-P03.vpl-ios27-2.json exit 0 (152 core and 46 experience tests on sim-27.2, slowest 0.93 s); written by an agent, retested
  invalid fixture gives `invalid(message)` and no pass drawn; reconnecting restores `ready`; a graph at 6 slots
  compiles and its bytes equal the registry's render-target bytes; 7 slots is refused with the registry unchanged;
  a 5-pass chain uses 2 slots; the preview hidden draws no pass and leaves the digest unchanged; a failing operator
  (a test seam replacing its text) gives `failed(message)` and the canvas keeps drawing

## Phase 4: Stories 4–5 — compile queue and rebuild (P2)

- [X] T-A23-307 [US4] [US5] Write `ExperienceTests/{CompileQueueTests,PreviewRebuildTests}.swift` (SC-A23-304, 305): N — Verified 2026-11-18: 2026-11-18: CompileQueueTests (2: six edits before a frame give one compile; a view change or a selection compiles nothing) and PreviewRebuildTests (3: 10 context rebuilds and a resize there and back byte-identical with leaked 0 and no extra compile; stills equal at one time and different at another; the grid covers the whole drawable after an inset frame); .autonomy/checks/A23-P03.vpl-ios27.json and A23-P03.vpl-ios27-2.json exit 0 (152 core and 46 experience tests on sim-27.2, slowest 0.93 s); written by an agent, retested
  edits before a frame give one compile; a view change gives none; 10 `recreateContext` and a resize there and back
  give a byte-identical inset with `leaked` 0; two stills at the same frame time are equal and at another time differ
  when Noise is fed by Time; after a frame with the inset the next frame's grid covers the whole drawable again

## Phase 5: Evidence

- [X] T-A23-308 Review checkpoint: `--name vpl-ios27` (both test targets on sim-27.2, each test under 10 s, — Verified 2026-11-18: 2026-11-18: review checkpoint: .autonomy/checks/A23-P03.vpl-ios27.json and A23-P03.vpl-ios27-2.json exit 0 (152 core and 46 experience tests on sim-27.2, slowest 0.93 s); A23-P03.documented-api.json, A23-P03.isolation.json and A23-P03.core-purity.json exit 0; the manifest test passes without regeneration
  SC-A23-306), the documented API, the isolation check and the core purity scan; regenerate `scenario-manifest.json`
  if the manifest test asks for it
- [X] T-A23-309 Contract: G-COMPILE, G-OPERATORS and G-BUDGET closed by "A23-P03", rows whose gaps are all closed — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P03.contract.json exit 0 (G-COMPILE, G-OPERATORS and G-BUDGET closed by A23-P03; M01, M02, M04, M07, M10, M15, M17, M20, M21 and M28 available with their notes)
  available with evidence (`--name contract`)
- [X] T-A23-310 The catalog, packages and script tests, `xcodegen generate`, the app build and unit tests (`--name — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P03.catalog.json, A23-P03.experience-packages.json and A23-P03.script-tests.json exit 0; xcodegen generate; A23-P03.app-unit.json exit 0 (build for testing and app unit tests on iOS 27.2); A23-P03.verify-27.json exit 0 (all 9 scenarios on iOS 27.2)
  app-unit`) and the runner (`--name verify-27`)
- [X] T-A23-311 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-18: 2026-11-18: /speckit-converge round 1 appended T-A23-312 (implemented; research D7 corrected), round 2 appended nothing (7 FR, 6 SC, 13 acceptance scenarios, 6 edge cases checked; every evidence file exit 0); .autonomy/evidence/A23-P03.json sealed; VERIFIED-GATE A23-P03 (168 of 263); planning index, matrix, distinctiveness, metadata, Auto-Creator, catalog (--check PASS), validate_autocreator and validate_docs PASS; README and docs/automatedtesting.md updated
  A23-P03; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

301 → 302 → 303 → 304 → {305, 306, 307} → 308 → 309 → 310 → 311.

## Parallel examples

- **Agent K:** 302. **Agent P:** 303–307 (against data-model.md; the lead relays K's final API).
- **Lead:** the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the compiler (302) with the pipeline and pixel tests (303–305).
- **Then:** the invalid and budget states (306), the queue and rebuild (307).
- **Review checkpoint:** at 308.
- **Commits:** one per task.

## Phase 6: Convergence

- [X] T-A23-312 Record the as-built design in `specs/168-vpl-p03-graph-compiler/{research.md,data-model.md,contracts/preview.md}`, per research D7, data-model and contracts/preview.md (contradicts, unrequested): — Verified 2026-11-18: 2026-11-18: research D7 corrected (RenderHost sets the viewport before each frame, line 419), as-built design recorded in data-model.md and contracts/preview.md (PassColour, blur directions and the shared blur program, keys, slots, kept slots on refusal, failed message, move recompiles, seams); .autonomy/checks/A23-P03.documented-api-2.json exit 0; docs only, A23-P03.vpl-ios27-2.json stands
  - research D7 corrected: `RenderHost` sets the viewport to the whole drawable before each frame (`RenderHost.swift` line 419, and `renderOffscreen`), so the inset's viewport never carries over; the grid drawn by a full-framebuffer `FieldPass` stays, harmless, and its test (`afterAnInsetFrameTheNextGridCoversTheWholeDrawable`) holds either way;
  - blur's direction is the floats `u_directionX` and `u_directionY`; both blur operators share one program, keyed by the program name "blur", because the registry caches programs by source; colours are `PassColour` (r, g, b); `Pass` and `PassSchedule` have public initialisers; keys use resolved parameter values, exclude positions and identities, and mark an input closing a loop "loop";
  - the presenter's seams `graphOverride`, the pipeline's `fragmentOverrides` and `runCount`; `LabTest.open` hides the preview by default so A23-P02's grid tests see the grid alone; a refused or invalid compile keeps the earlier slots; the failed message is "The preview could not be drawn: <diagnostic>"; a node move recompiles once (the fingerprint holds positions) without changing slots or programs.
