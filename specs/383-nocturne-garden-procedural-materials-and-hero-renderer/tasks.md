# Tasks: R02-G09-03 — Nocturne Garden: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G09-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G09-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_383;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0903-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0 on the committed tree; rendering baseline is R02-G09-02's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G09-02's
  rendering runs (exit 0)
- [X] T-R02G0903-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies VisualCoreScenes, — Verified 2026-11-22: host exit=0 (87 Nocturne Garden tests: kernel suites unchanged; Core gains VisualCoreScenes, Experience, Diagnostics, Persistence; the invariant tests' kernel scan skips the five presentation sources; snapshot, palette and tiers)
  VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence now; `NocturneGardenExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); make the kernel scan of
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenInvariantTests.swift` skip the presentation sources (snapshot, geometry, shaders,
  scenarios, adapter), which use Doubles; create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneSnapshot.swift` (snapshot per
  data-model.md: width, height, target, forbidden, shadow and leaking cells as sorted arrays, blooms, sun, stage,
  failure, moves, budget, levelNumber, time; `NocturneGardenTier` "level-0: 3 mist layers, stem depth 3, feather 0.3,
  2 glow shells; level-1: 2, 2, 0.15, 1; level-2: 1, 1, 0, 0; richest first"; `NocturneGardenPalette` "ground #0A1230,
  mist #B8C4E0, mistHighlight #E6ECF7, shadow #05060A, gold #E8C872, coral #FF7A5C, leak #FF3B30, body #10131C, glow
  #FFB88A, lantern #FFD9A0, spent #FF7A5C, unspent #3A4558"); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter NocturneGarden`

## Phase 2: Stories 1 and 2 — the garden and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [X] T-R02G0903-003 [P] [US1] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenShaders.swift` (garden and glow sources, GLSL ES 3.00; — Verified 2026-11-22: host-2 exit=0 (NocturneGardenShaderSourceTests 16: version and precision, uniforms declared and used with types, at most 16 vec4 slots, no samplers or discard, constant loop bounds, palette constants equal the CPU's, material codes 0-11, feathered shadow, mist and sway on u_time alone, hatch, glow gain per tier and Reduce Flashing limit; agent A's files retested by the lead)
  pearlescent mist with up to 3 drifting layers driven by `u_time`; deep black shadow with a feathered edge;
  gold target rim; coral forbidden hatch and leak cross; dark botanical bodies with coral-gold rims; lantern; uniform
  names; glow gain cap; palette constants equal to the CPU's) with `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenShaderSourceTests.swift`
  (version line, declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants
  match); agent A; `--name host-2`
- [X] T-R02G0903-004 [P] [US1] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneGeometry.swift` (the bed upright at z = 0 with cell — Verified 2026-11-22: host-3 exit=0 (NocturneGardenSceneGeometryTests 12: finite and bounded for the empty bed and a 32x24 bed of 12 size-3 blooms ending in a leak, every place inside the view with margin at 7 aspects, the clarified formulas, positions equal at every tier, time and Reduce Motion, shadow quads equal the mask, bloom vertices inside their boxes, gauge bars, glow empty at level-2, head triangulation, leak crosses only after a leak; agent B's files retested by the lead)
  size u = 2 / W, cell (c, r) from x = −1 + c·u, y = r·u; a shadow quad per mask cell with a feather band along
  boundary edges of the tier's width; gold rim on the target's boundary edges; coral hatch on forbidden cells; a cross
  on leaking cells after a leak failure; each bloom at z = 0.35: its kind's outline at size·u anchored at the anchor
  cell's lower-left corner, extruded 0.04 with a rim, and an L-system stem of the tier's depth with a leaf pair per
  level; the lantern at x = 1.25, y = (1.15 − 0.25·(e − 1))·H·u; the gauge of `budget` bars at y = −0.1 from x = −0.9
  to 0.9, spent ones coral; ground y = −0.2; camera from +z pitched 8° fitted per level to the sphere of the bed widened
  by the largest head (s·u left, 2·s·u right, 6·s·u above), the lantern and the gauge with a 5 % margin for aspect 0.4
  … 2.5; `project`; `bloomBox`; mist drift and sway by uniforms, still under Reduce Motion) with
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenSceneGeometryTests.swift` (finite and bounded for extreme settings — the empty bed and a
  bed of 12 size-3 blooms at row H − 1; every cell centre, the lantern and the gauge inside the view with margin at 7
  aspects; same positions at every tier; shadow quads equal the mask; gauge bars at 0, half and the budget); agent B;
  `--name host-3`
- [X] T-R02G0903-005 [P] [US2] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenExperienceCore.swift` (controls "bloom.plant [0 … 5, — Verified 2026-11-22: host-4 exit=0 (NocturneGardenExperienceCoreTests 13 + NocturneGardenRendererPurityTests 2: conformance, controls and tiers, every action applied or refused with its code, undo restores the digest, snapshot round trip and refusals, the candidate table equals the 100 witnesses' skipped, 200 seeded snapshots never change digest or verdict; agent C's files retested by the lead)
  column, row, size], bloom.move [bloom, column, row], bloom.resize [bloom, size], bloom.remove [bloom], sun.set
  [elevation], play.undo, play.redo, level.next"; digest "level number and play fingerprint"; schema 1
  `{level, records}`; quality profile of three levels; each level certified directly from a table of its witness's
  `skipped` candidate, the whole generator only if that fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenExperienceCoreTests.swift` (conformance; undo restores the digest; snapshot round trip and
  refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenRendererPurityTests.swift` (200 seeded snapshots: tier, time and snapshot never change
  digest or verdict); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks pass.

- [X] T-R02G0903-006 [US3] [US4] Create `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenExperience.swift`, `…Presenter.swift`, — Verified 2026-11-22: sim-27 exit=0 (NocturneGardenExperienceTests, 32 tests in 4 suites on iOS 27.2: frames vs the CPU reference at three tiers on levels 1, 21, 41, 61, 81, tier positions and log, fallback, resize and zero size, memory warning, Reduce Motion and Flashing, leak crosses, identity); a first run showed the full-size heads hid their own shadows (level 1: 96 of 192 cells behind blooms, 180 when won), so the head is drawn at 0.35·size·u (spec Q1 corrected; geometry and test boxes follow); packages, catalog-search and host-5 (136 Nocturne Garden host tests incl. 6 scenario tests) exit 0; agent D's tests retested by the lead
  `…GardenScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce Flashing;
  the presenter declares `probes(_:)` — two ground corners, as the round-two X gates require — and its quality levels
  equal the Core's `qualityTiers`), `…Controls.swift` (labelled kind picker, column and row − and +, size, plant,
  bloom picker, move, resize, remove, sun − and +, undo, redo, next level; defaults first supplied kind, column 0, row 0,
  smallest size, bloom 0, clamped after each action, undo or redo), `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenScenarios.swift` (standard
  scenarios, full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G09-QA-001 … 080) with
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenScenariosTests.swift` and `Packages/ExperiencesRound02/NocturneGarden/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example →
  `r02-g10.backwards-aurora`, `scripts/test_scripts.py`); agent D writes `Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/` (render vs CPU
  reference at 1,152 × 768 at three tiers on 5 levels after the witness's first plant, at cell centres outside every
  bloom's box: every shadow cell (± 3 px) darker than the mist by 0.15 in luminance, every forbidden cell outside the
  shadow with red minus blue ≥ 0.15, every target cell outside the shadow 0.15 brighter than a shadow cell, the gauge's
  first bar differs from the ground by 0.1, ground background within 0.05; tier coordinates; fallback; resize and zero
  size; memory warning releases and the next frame rebuilds; Reduce Motion; a leak failure crosses its cells; identity);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing NocturneGardenExperienceTests`;
  `--name packages -- python3 scripts/check_experience_packages.py`; `--name catalog-search -- swift test
  --package-path Packages/VisualCore --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary
  feeds catalog search and stays ≤ 300 characters)

## Phase 4: Regression, documentation and close

- [X] T-R02G0903-007 Docs: `docs/architecture/nocturne-garden.md` (renderer and experience), — Verified 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; docs/architecture/nocturne-garden.md experience and renderer, ExperiencesRound02 README feature 383, docs/automatedtesting.md entry; validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0903-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0903-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: 2026-11-22: reference-1 exit 0
- [ ] T-R02G0903-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0903-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0903-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G0903-006)
- [ ] T-R02G0903-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.
