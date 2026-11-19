# Tasks: Effects Composer — Phase 03 Chain editing, compare and presets

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/presets.md](contracts/presets.md), [quickstart.md](quickstart.md). Gate A25-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A25-P03 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers. **Checks:** read every exit before ticking.
- **Scope:** no VisualCore change. **Precedent:** `specs/169-vpl-p04-graph-library`. **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A25-301 Baseline: cite the A25-P02 evidence (`.autonomy/checks/A25-P02.{ec-ios27,app-unit,verify-27}.json`) — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P02.{ec-ios27,app-unit,verify-27}.json exit 0

## Phase 2: Story 2 — save a look and open it again (P1) 🎯

- [X] T-A25-302 [P] [US2] Create `Packages/ExperiencesCreative/EffectsComposer/Experience/LookLibrary.swift` per clarification Q2 (files, index, 24 presets, — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P03.ec-ios27.json exit 0 (44 core and 45 experience tests on sim-27.2); LookLibrary per clarification Q2
  names 1…40 unique ignoring case, refusals `damaged`, `newer-version`, `too-large` and the chain file's codes,
  the four messages, newest first, read-only on a newer index, never deleting automatically)
- [X] T-A25-303 [US2] Write `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/LookLibraryTests.swift`: save and open round-trip (equal, same — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P03.ec-ios27.json exit 0 (44 core and 45 experience tests on sim-27.2); LookLibraryTests 7 (round trip, caps, names, damaged/newer/oversized kept byte-identical, read-only index, rebuilt index, full quota)
  fingerprint); rename; remove; the 25th save, an empty or 41-character name and a duplicate name are refused and
  change nothing; damaged, newer and oversized files are listed as unreadable and stay byte-identical; a newer index
  makes the library read only; a damaged index is rebuilt only by the next change; a full storage quota refuses a save
  with "There is not enough space to save this preset." and writes nothing
- [X] T-A25-304 [US2] Add `ChainEdit.replace` to `Packages/ExperiencesCreative/EffectsComposer/Core/ChainEditing.swift` and its tests to — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P03.ec-ios27.json exit 0 (44 core and 45 experience tests on sim-27.2); ChainEdit.replace with undo and redo; presenter library actions; open then undo returns the chain before opening (PresetPresenterTests); staging actions recorded in contracts/presets.md
  `Packages/ExperiencesCreative/EffectsComposer/CoreTests/HistoryTests.swift` (replace then undo returns the earlier chain exactly), and the presenter's library
  actions (opening a preset through the presenter, then undo, returns the chain before opening) and the inline `presets`
  controls in `Packages/ExperiencesCreative/EffectsComposer/Experience/{ComposerPresenter,ECControls}.swift` per clarification Q3

## Phase 3: Story 1 — compare (P1)

- [X] T-A25-305 [US1] Add `view.compare` to `Packages/ExperiencesCreative/EffectsComposer/Experience/Adapter/ComposerCore.swift`, the compare present path to — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P03.ec-ios27.json exit 0 (44 core and 45 experience tests on sim-27.2); CompareTests: on shows the source, off the result, empty chain the source, source shown again after recreateContext
  `Packages/ExperiencesCreative/EffectsComposer/Experience/PreviewRenderer.swift` and the `compare` toggle to `ECControls` per clarification Q1; write
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/CompareTests.swift`: on shows the source's pixels, off the result's; empty chain both the source;
  after `recreateContext` with compare on the source is shown again

## Phase 4: Stories 3 and 4 — no aliasing; edit without dragging (P1, P2)

- [X] T-A25-306 [US3] Write `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/AliasingTests.swift` per clarification Q4: `FieldPass.runObserver` over 50 — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P03.ec-ios27.json exit 0 (44 core and 45 experience tests on sim-27.2); AliasingTests: 166 passes over 50 edits, none reads its output or writes the source
  edits of every kind with compare toggled every 5 and a frame after each; no input equals the output and no output is
  the source's texture
- [X] T-A25-307 [US4] Add `ComposerLabels.actions(for:)` and the named accessibility actions to `ECControls` per — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P03.ec-ios27.json exit 0 (44 core and 45 experience tests on sim-27.2); AccessibilityActionTests: action lists for first, middle and last nodes; 21 actions applied, each changes the chain as named
  clarification Q5; write `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/AccessibilityActionTests.swift`: the actions listed for the first, a middle
  and the last node, and applying each changes the chain as named and redraws

## Phase 5: Evidence

- [X] T-A25-308 Review checkpoint: `--name ec-ios27` (both test targets), the documented API, isolation and core purity — Verified 2026-11-19: 2026-11-19 review checkpoint: .autonomy/checks/A25-P03.{ec-ios27,documented-api,isolation,core-purity}.json exit 0
- [X] T-A25-309 Contract: G-EDIT, G-COMPARE and G-PRESETS closed by "A25-P03"; G-PRESETS's phase 3, G-IMPORT and — Verified 2026-11-19: 2026-11-19 G-EDIT, G-COMPARE and G-PRESETS closed by A25-P03 (M08, M09, M18, M19, M20 available); G-IMPORT and U-RGBAUPLOAD phase 4, G-EXPORT phase 5, traceability phases follow the manual's gates; .autonomy/checks/A25-P03.contract.json exit 0
  U-RGBAUPLOAD phase 4, G-EXPORT phase 5 (`--name contract`); README of the experience
- [X] T-A25-310 `--name catalog`, `experience-packages`, `script-tests`; `xcodegen generate --spec project.yml`, then — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P03.{catalog,experience-packages,script-tests,app-unit-2,verify-27}.json exit 0 (app-unit failed first: the dependency audit denies 'presetlibrary', fixed by renaming to LookLibrary)
  `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; `--name verify-27`
- [ ] T-A25-311 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A25-P03; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

301 → {302, 305}; 302 → 303 → 304; {304, 305} → {306, 307} → 308 → 309 → 310 → 311.

## Parallel examples

- **Agent L:** 302, 303. **Agent V:** 304–307 (after 302 for the presenter actions). **Lead:** runs, contract, commits.

## Implementation strategy

- **MVP:** presets (302–304) and compare (305). **Then:** the audit and the actions. **Checkpoint:** 308.
