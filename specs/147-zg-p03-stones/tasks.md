# Tasks: Digital Zen Garden — Phase 03 Stone manipulation and undo

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/stones.md](contracts/stones.md), [quickstart.md](quickstart.md). Gate A20-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A20-P03 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore change. Precedent: `specs/140-lw-p03-editor/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A20-301 Baseline: cite the A20-P02 evidence (`.autonomy/checks/A20-P02.{zg-ios27-2,app-unit,verify-27}.json`) on the tree recorded at A20-P02 (`6f236139`), whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A20-P02 evidence cited: .autonomy/checks/A20-P02.zg-ios27-2.json, A20-P02.app-unit.json and A20-P02.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A20-P02 record commit 6f236139

## Phase 2: Foundational — the pure stone model

- [X] T-A20-302 [P] Create `Packages/ExperiencesCreative/DigitalZenGarden/Core/{StoneShape,StoneLayer,StoneSelection}.swift` per data-model.md ("exponents river-pebble 2.0, flat-slate 2.6, round-granite 2.0, tall-basalt 3.0, moss-boulder 2.2; heights 0.6, 0.35, 0.7, 1.0, 0.8; wobble ≤ 6 % seeded by the id"; the layer "480 × 360 in ascending depth"; topmost and cycle) and `CoreTests/{StoneShapeTests,StoneLayerTests,SelectionTests}.swift` (contains at the centre, not outside the bounds, rotation and scale respected, wobble bounded and deterministic; a higher stone overwrites a lower one; topmost in every overlap sample, nil on empty sand, cycle wraps in depth order) (FR-A20-301–303; SC-A20-302) — Verified 2026-11-17: 2026-11-17: Core/StoneShape.swift (exponents, heights, wobble at most 6 percent seeded by the id, contains, height, bounds, outline), StoneLayer.swift (480 x 360 in ascending depth), StoneSelection.swift (topmost, cycle, place) and CoreTests StoneShapeTests, StoneLayerTests, SelectionTests pass in .autonomy/checks/A20-P03.zg-ios27.json exit 0 (51 core tests, iOS 27.2); written by an agent, retested

## Phase 3: Story 1 — place, move, rotate, remove (P1) 🎯

- [X] T-A20-303 [US1] Extend `Packages/ExperiencesCreative/DigitalZenGarden/Experience/{Adapter/GardenCore.swift,SandScene.swift}`: the six actions of clarification Q2 through `GardenHistory` (one command each; refusals without a selection; the stone cap message "The garden holds 24 stones."; moves clamped inside the tray); the stone target uploaded from `StoneLayer` and rebuilt on stone change, undo, redo, restore, resize and context loss; stone shading by kind and the five-tap soft shadow in the relief pass (FR-A20-301, 302, 306) — Verified 2026-11-17: 2026-11-17: GardenCore stone.place, stone.select (by id), stone.move, stone.rotate, stone.remove and tool.mode as single GardenHistory commands (refusals unchanged; a20.no-selection, a20.unknown-stone, a20.stone-cap with the message The garden holds 24 stones.; clamping; placing selects the new stone); SandScene second uploaded stone target rebuilt on every change, stone shading by kind and a five-tap soft shadow; written by an agent, retested
- [X] T-A20-304 [US1] Write `Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/{StoneActionTests,StoneRenderTests}.swift`: each stone action undone and redone gives equal documents; refusals unchanged; the cap; clamping; the stone target reads back within 1/1024 of `StoneLayer`; the sand under a stone's shadow is darker than without the stone; undo, redo and a context recreation rebuild the same picture (SC-A20-301) — Verified 2026-11-17: 2026-11-17: ExperienceTests StoneActionTests and StoneRenderTests (each action undone and redone equal; refusals; cap; clamping; read-back within 1/1024; shadowed sand darker; undo, redo and context recreation rebuild the same picture) pass in .autonomy/checks/A20-P03.zg-ios27.json exit 0 (55 experience tests); written by an agent, retested

## Phase 4: Story 2 — layer-aware selection (P1)

- [X] T-A20-305 [US2] Extend `Packages/ExperiencesCreative/DigitalZenGarden/Experience/{GardenPresenter.swift,GardenControls.swift,BrushPreview.swift}`: the tool mode; in the stone tool a tap selects, a drag from the selected stone shows the move and sends one `stone.move` on lift, a two-finger rotation (`RotateRecognizer`) sends one `stone.rotate` at its end, a cancel sends nothing; the native controls of clarification Q3 with spoken labels and the selection value "<kind> selected, <n> of <count>, turned <degrees>°"; the dashed outline of the selected stone in the overlay; gesture actions ⊆ native actions; and `ExperienceTests/StoneGestureTests.swift` (tap sends `stone.select` with the topmost stone's id, empty sand sends 0, an unknown id is refused, drag sends one move, rotation one turn, cancel nothing, removing the selected clears it) (FR-A20-303, 304) — Verified 2026-11-17: 2026-11-17: GardenPresenter (tool mode; tap selects the topmost by id; one move on lift; one turn at the rotation end via RotateRecognizer; a cancel sends nothing), GardenControls (tool toggle, kind picker and Place, previous and next, turn 15 degrees, nudges 0.02, Remove; the spoken selection value), BrushPreview (dashed outline with the kind's name); gesture actions within native actions; ExperienceTests/StoneGestureTests.swift and the updated PointerPathTests pass in .autonomy/checks/A20-P03.zg-ios27.json exit 0; written by an agent, retested

## Phase 5: Story 3 — orientation keeps the garden (P1)

- [X] T-A20-306 [US3] Write `Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/OrientationTests.swift`: the same document drawn in 390 × 844 and 844 × 390 views gives an unchanged document, identical sand and stone layers, and every stone centre and stroke point mapped to the view and back within 1/480 tray widths (FR-A20-305; SC-A20-303) — Verified 2026-11-17: 2026-11-17: ExperienceTests/OrientationTests.swift (390 x 844 and 844 x 390 views: the document unchanged, sand and stone layers identical, stone centres and stroke points round-trip within 1/480 tray widths) passes in .autonomy/checks/A20-P03.zg-ios27.json exit 0; written by an agent, retested

## Phase 6: Records and evidence

- [X] T-A20-307 Extend `Experience/Adapter/GardenManifest.swift` with stone fixtures (placed stone, moved, rotated, removed and undone) and regenerate `scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), then the plain run; Digital Zen Garden tests on sim-27.2 (`--name zg-ios27`), documented API, isolation and core purity (SC-A20-304) — Verified 2026-11-17: 2026-11-17: GardenManifest stone fixtures (fixture-stone-placed, -moved, -rotated, -removed, -remove-undone) and six rejection entries; scenario-manifest.json regenerated and matched on the plain run; .autonomy/checks/A20-P03.zg-ios27.json, A20-P03.documented-api.json, A20-P03.isolation.json and A20-P03.core-purity.json exit 0; written by an agent, retested
- [X] T-A20-308 Contract: G-STONES (with the rasterized-layer decision of clarification Q1), G-SELECTION and G-SHADOWS closed by "A20-P03"; rows whose gaps are all closed become available with evidence; the stone shading row in `docs/apps/digital-zen-garden/licenses.md` (`--name contract`) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P03.contract.json exit 0 (PASS: 31 rows, 175 citations, 14 gaps); G-STONES (with the rasterized-layer decision of clarification Q1), G-SELECTION and G-SHADOWS closed by A20-P03; M06, M08, M17, M18, M19 and M23 available with evidence; the stone shading row in licenses.md
- [X] T-A20-309 Catalog, app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit`), runner (`--name verify-27`), packages and script tests — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P03.catalog.json, A20-P03.app-unit.json (xcodegen generate; app-build-for-testing-ios27 and app-unit-ios27 pass), A20-P03.verify-27.json (0 failures on 27.2), A20-P03.experience-packages.json and A20-P03.script-tests.json, all exit 0, each read before this tick
- [ ] T-A20-310 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A20-P03; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

301 → 302 → 303 → 304 → 305 → 306 → 307 → 308 → 309 → 310. 302 is the core (its own writer); 303–307's sources are one
experience (one writer).

## Parallel examples

Agent C: T-A20-302 (core). Agent E: T-A20-303–306 and the manifest source of 307 (experience) after C. Lead: runs,
manifest regeneration, contract, commits.

## Implementation strategy

MVP: stone commands and drawing (302–304). Selection (305) and the orientation fixture (306) close the manual's gates.
Review checkpoints after 304 and at 307.
