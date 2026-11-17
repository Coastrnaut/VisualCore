# Tasks: Digital Zen Garden — Phase 01 Document and stroke math with fixtures

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/core.md](contracts/core.md), [quickstart.md](quickstart.md). Gate A20-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A20-P01 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore or ProjectM change. Precedent: `specs/138-lw-p01-export-contract/tasks.md`. Rollback: revert the commits (no
stored data exists yet).

## Phase 1: Setup

- [X] T-A20-101 Baseline: cite the A20-P00 evidence (`.autonomy/checks/A20-P00.{app-build,no-change,experience-packages}.json`) on an unchanged `Packages` tree instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A20-P00 evidence cited: .autonomy/checks/A20-P00.app-build.json, A20-P00.no-change.json and A20-P00.experience-packages.json, all exit 0; no Packages, Apps or project.yml change since the A20-P00 record commit 71992be8
- [X] T-A20-102 Add the targets `DigitalZenGardenCore` (path `DigitalZenGarden/Core`, dependencies `VisualCoreMath` and `VisualCoreExperience`) and `DigitalZenGardenCoreTests` (path `DigitalZenGarden/CoreTests`, dependencies the core and `VisualCoreMath`) to `Packages/ExperiencesCreative/Package.swift` (lead), with a comment naming feature 145 and "a pending core until A20-P02 adds the experience" — Verified 2026-11-17: 2026-11-17: DigitalZenGardenCore (VisualCoreMath, VisualCoreExperience) and DigitalZenGardenCoreTests (the core, VisualCoreMath) in Packages/ExperiencesCreative/Package.swift with the feature 145 pending-core comment; the package builds and tests in .autonomy/checks/A20-P01.zg-core-1.json exit 0

## Phase 2: Story 1 — a garden is a small, safe file (P1) 🎯

- [X] T-A20-103 [P] [US1] Create `Packages/ExperiencesCreative/DigitalZenGarden/Core/GardenPalette.swift` per data-model.md: tray `small-tray` (aspect 4:3, field 160 × 120); tones `pale`, `warm`, `grey` ("opaque sRGB, components in 0…1"); rake styles `fine-rake` (5 tines, width 0.06, depth 0.6) and `wide-rake` (3 tines, width 0.10, depth 1.0); five stone kinds with base radii "in 0.01…0.08"; lookup by id; `///` on every public symbol — Verified 2026-11-17: 2026-11-17: Core/GardenPalette.swift (small-tray 4:3 with a 160 x 120 field and y scale 0.75; tones pale, warm, grey; fine-rake 5 tines 0.06 depth 0.6, wide-rake 3 tines 0.10 depth 1.0; five stone kinds with radii in 0.01...0.08; lookups and defaults); written by an agent, retested
- [X] T-A20-104 [P] [US1] Create `Packages/ExperiencesCreative/DigitalZenGarden/Core/GardenDocument.swift` per data-model.md: `RakeStroke` ("1…512 points, each coordinate finite and in 0…1"), `Stone` (unique id and depth; position 0…1, rotation −π…π, scale 0.5…2), `GardenDocument` (schema 1, envelope kind `a20.garden`, "≤ 24" stones, "≤ 400" strokes, `nextStoneID`, the 262,144-byte limit, `encoded()` with sorted keys, `decode(_:)` checking size, envelope, version, body, then values) and `DocumentRefusal` with the nine codes and sentences — Verified 2026-11-17: 2026-11-17: Core/GardenDocument.swift (RakeStroke with 512 points, Stone with its ranges, GardenDocument schema 1 kind a20.garden with 24 stones, 400 strokes, 262,144 bytes, sorted-key envelope, decode checking size, envelope, version, body and values; DocumentRefusal with nine codes and sentences); written by an agent, retested
- [X] T-A20-105 [P] [US1] Write `Packages/ExperiencesCreative/DigitalZenGarden/CoreTests/{PaletteTests,DocumentTests}.swift`: counts, unique ids, ranges and opacity; document round trip exact; one sample per refusal leaving the open garden unchanged (FR-A20-101, 102, 104; SC-A20-101) — Verified 2026-11-17: 2026-11-17: CoreTests/PaletteTests.swift and DocumentTests.swift (counts, ids, ranges, opacity; exact round trip; one sample per refusal code; a refusal leaves the open garden unchanged) pass in .autonomy/checks/A20-P01.zg-core-1.json exit 0 (24 tests, iOS 27.2); written by an agent, retested

## Phase 3: Story 2 — strokes without gaps, two rakes (P1)

- [X] T-A20-106 [P] [US2] Create `Packages/ExperiencesCreative/DigitalZenGarden/Core/{StrokeResampler,RakeBrush,SandField}.swift` per data-model.md and clarifications Q2–Q3: resampling at 0.004 tray widths (y scaled by 0.75), cap 512 with `capped`, repeated points (< 1e-6) dropped, clamping to 0…1, a non-finite point refuses; the groove profile depth·cos(2π·tines·u/width) for |u| ≤ width/2 replacing the height under the footprint; the 160 × 120 field at rest 0 with `replay(_:)` and `maxDifference(_:)` — Verified 2026-11-17: 2026-11-17: Core/StrokeResampler.swift (0.004 tray widths with y scaled 0.75, cap 512 with capped, repeats under 1e-6 dropped, clamping, non-finite or empty input refused), RakeBrush.swift (the cosine profile replacing the height in a footprint one spacing long and the rake's width across, bounding box only) and SandField.swift (160 x 120 at rest 0, apply, replay, maxDifference); written by an agent, retested
- [X] T-A20-107 [P] [US2] Write `Packages/ExperiencesCreative/DigitalZenGarden/CoreTests/{ResamplerTests,RakeTests}.swift`: a fast, sparse path gives neighbours at most 0.004 + 1e-9 apart; the cap; clamping; non-finite refusal; a dab; the two styles' grooves differ in width and tine count; a stamp changes only cells within its footprint (FR-A20-103, 104; SC-A20-102) — Verified 2026-11-17: 2026-11-17: CoreTests/ResamplerTests.swift (6 tests: gaps at most 0.004 + 1e-9, cap, clamping, refusals, dab, repeats) and RakeTests.swift (5 tests: the styles differ in ridge count and band width, a stamp changes only its footprint, deterministic replay, later strokes overwrite) pass in .autonomy/checks/A20-P01.zg-core-1.json exit 0; written by an agent, retested

## Phase 4: Story 3 — exact undo and redo (P1)

- [ ] T-A20-108 [US3] Create `Packages/ExperiencesCreative/DigitalZenGarden/Core/GardenHistory.swift` per data-model.md and clarification Q4: commands `rake`, `place`, `move`, `rotate`, `remove`, `tone` (each recording what its undo needs); `apply(_:)` refusing over-cap, unknown and out-of-range commands and commands on a missing id without a change; `undo()`, `redo()` (a new command clears redo); at most 100 undoable commands, the oldest folding into the checkpoint (document and field); `field()` rebuilt from the checkpoint
- [ ] T-A20-109 [US3] Write `Packages/ExperiencesCreative/DigitalZenGarden/CoreTests/{HistoryTests,ReplayFixtureTests}.swift`: 60 mixed commands undone and redone give an identical command list and a field within 1e-6 per cell; redo cleared; empty undo and redo change nothing; 150 commands fold into the checkpoint and the rebuilt field equals a full replay within 1e-6; refusals leave the document unchanged (FR-A20-105, 106; SC-A20-103, 104)
- [X] T-A20-110 [P] Write `docs/apps/digital-zen-garden/licenses.md` (the tray, tones, rake styles and stone kinds are written in this repository; numbers only; no third-party asset) — Verified 2026-11-17: 2026-11-17: docs/apps/digital-zen-garden/licenses.md (tray, tones, rake styles, stone kinds and the groove profile written in this repository; numbers only; no third-party asset; shaders and sound listed when added); validate_docs exit 0; written by an agent, reviewed

## Phase 5: Records and evidence

- [ ] T-A20-111 Core tests on sim-27.2 (`--name zg-core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalZenGardenCoreTests`; each test under 10 s) and the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/DigitalZenGarden`); a purity scan of the core (`--name core-purity -- sh -c '! grep -rnE "import (UIKit|SwiftUI|OpenGLES|Network)|URLSession|Date\(\)|ContinuousClock|CFAbsoluteTime" Packages/ExperiencesCreative/DigitalZenGarden/Core'`) (FR-A20-107; SC-A20-105)
- [ ] T-A20-112 Contract `docs/apps/digital-zen-garden/visualcore-contract.json`: G-DOCUMENT, G-STROKES and G-UNDO closed by "A20-P01"; rows whose gaps are all closed become available with evidence (`--name contract -- python3 scripts/check_app_contract.py --app digital-zen-garden --render`)
- [ ] T-A20-113 Packages, catalog, script tests, no-change and the app build (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name catalog -- python3 scripts/build_catalog.py --check`; `--name script-tests -- python3 scripts/test_scripts.py`; `--name no-change -- git diff --exit-code --stat c2fad427..HEAD -- Packages/VisualCore Packages/VisualCoreRendering External`; `--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) (FR-A20-107)
- [ ] T-A20-114 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A20-P01; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A20-101 → 102 → {103, 104, 106} → {105, 107} → 108 → 109 → 111 → 112 → 113 → 114. 103/104/106 and 105/107 are
separate files and may run in parallel; 108 needs 104 and 106; 110 is independent.

## Parallel examples

Agent G: T-A20-103, 104, 105 (palette, document and their tests). Agent S: T-A20-106, 107 (resampler, rakes, field and
their tests). Agent H: T-A20-108, 109 after G and S hand over. Agent D: T-A20-110. Lead: Package.swift (102), runs,
contract, commits.

## Implementation strategy

MVP: the document (103–105). Strokes and rakes (106, 107) and the history with its fixture (108, 109) close the manual's
regression rule. Review checkpoints after 107 and at 109 (fixture passes).
