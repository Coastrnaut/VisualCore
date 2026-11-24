# Tasks: R02-G14-03 — Moonlit Mechanism: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G14-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_433;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1403-001 Baselines on the committed tree after R02-G14-02 is recorded: `--name baseline-host`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on caab4ed3c (.autonomy/migration/checks/R02-G14-03.baseline-*.json); rendering baseline = R02-G14-02 rendering-27/26
  baseline-timing`, `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering
  baseline is R02-G14-02's rendering runs (exit 0)
- [X] T-R02G1403-002 Edit `Packages/ExperiencesRound02/Package.swift` (`MoonlitMechanismCore` gains VisualCoreScenes, — Verified 2026-11-24: 2026-11-24: Core gains VisualCoreScenes/Experience/Diagnostics/Persistence; snapshot, palette and tiers; the invariant scans already read only the five named kernel files, so the presentation sources are outside them; host exit 0, 88 tests (.autonomy/migration/checks/R02-G14-03.host.json)
  VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; `MoonlitMechanismExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); make the renderer-purity and
  time scans of `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismInvariantTests.swift` skip the
  presentation sources (snapshot, geometry, shaders, scenarios, adapter), which use Doubles and other imports; create
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSceneSnapshot.swift` (snapshot per data-model.md:
  gears, phases at the shown key frame, height, lampHeights, width, rows, shownFrame, cast, target, forbidden, run
  report, stage, failure, actionsLeft, budget, levelNumber, time; `MoonlitMechanismTier` "level-0: 6 segments per tooth,
  soft edge, 2 glow shells; level-1: 4 segments, soft edge, 1 glow shell; level-2: 2 segments, none; richest first";
  `MoonlitMechanismPalette` "night #070A14, paper #E8DFC8, ink #1A1822, gear #C9A24A, rim #E2C277, blade #B08A3C, lamp
  #8FB4E8, lampGlow #B7CFF2, target #4A6FA8, forbidden #B03A3A, stray #7A3A5A, broken #FF6B4A, cardLit #C9A24A,
  cardUnlit #2A2A38, alignLit #8FB4E8, alignUnlit #2A2A38, movesLit #E2C277, movesUnlit #2A2A38, glow #F2E2B0; gear
  alpha 0.6, blade alpha 0.5"); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  MoonlitMechanism`

## Phase 2: Stories 1 and 2 — the clockwork and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [ ] T-R02G1403-003 [P] [US1] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismShaders.swift`
  (clockwork and glow sources, GLSL ES 3.00; signed-distance shading of teeth, notch, spokes, shadow edges, outlines,
  crossed marks, hatching and gauges from per-vertex local coordinates; translucent gold with a fresnel-like rim on the
  gears; the soft shadow edge fading ink to paper at level-0 and level-1 only; the glow program shades the lamp and the
  lit cards; a won level lifts the wall's glow; uniform names; glow gain cap; palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismShaderSourceTests.swift` (version line,
  declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match); agent A;
  `--name host-2`
- [ ] T-R02G1403-004 [P] [US1] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSceneGeometry.swift`
  (clarification Q1: the wall a vertical plane at z = −0.6, cell size s = min(1.8 / W, 1.2 / H), cell (c, r) at x =
  (c − (W − 1)/2) · s, y = 0.65 − (r − (H − 1)/2) · s; night backdrop at z = −0.62 over x −1.2 … 1.2, y −0.5 … 1.7; the
  paper wall; the shown key frame's cast cells as ink squares of side 0.92 s with a feather quad 0.15 s wide at level-0
  and level-1; target cell borders 0.08 s wide, missing target cells dotted and stray cells hatched when the run report
  names them; forbidden cells crossed; gears deepest first at z = −0.6 + 0.12 · depth, centred on their centre cell
  (unshifted by the lamp), rims of radius 3.4 s with T teeth of height 0.35 s (segments per tooth by tier) rotated by
  phase · 360° / T clockwise for direction +1 and anticlockwise for −1, a tooth-zero notch, solid blades as translucent
  spokes along their slot rays; the lamp disc of radius 0.06 at x = 0, y = 1.30 + 0.03 · height, z = 0.35 with a ladder
  of `lampHeights` rungs; key-frame cards at y = −0.18 from x = −0.6 to 0.6, lit by covered fraction, required ones with
  a gold border, the shown one raised; alignment pips at y = −0.30 from x = −0.3 to 0.3, lit when aligned; moves bars of
  `budget` at y = −0.40 from x = −0.9 to 0.9, each 1.8 / budget wide with a fifth as gap, 0.04 tall, lit for the actions
  left; a failure outlines the jammed pair's teeth, the forbidden cell or the failing card in the broken colour; a won
  level brightens the wall without moving any position; `glowMesh` per tier (2, 1, 0 shells around the lamp and lit
  cards); camera from eye (0, 0.65, 2.4) to (0, 0.55, −0.3) fitted to x −0.95 … 0.95, y −0.45 … 1.5, z −0.6 … 0.4 with a
  5 % margin for aspect 0.4 … 2.5; `project`; the CPU reference points (cast-cell centres, gear rim check points at the
  notch angle plus half a tooth, 0.2 s inside the rim, the first card, pip and moves bar); fallback coloured parts) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismSceneGeometryTests.swift` (finite and bounded
  for extreme settings — 2 and 5 gears, 6 and 20 teeth, walls 8 × 6 and 24 × 16, every lamp height, budgets 1 and 40, 2
  and 6 key frames; every cast cell, gear, card, pip and bar inside the view with margin at 7 aspects over the catalog's
  levels; the same positions at every tier; the ink squares exactly the kernel's cast cells for the shown key frame;
  gear rotation follows phase and direction; gauges at 0, half and the budget; a won level brighter and in place; the
  glow mesh empty at level-2 and its shell counts per tier; only segments, feathers and glow differ between tiers);
  agent B; `--name host-3`
- [ ] T-R02G1403-005 [P] [US2] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismExperienceCore.swift`
  (controls "handle.turn [±1], gear.reseat [g, ±1], lamp.step [±1], machine.run, play.undo, play.redo, level.next,
  frame.show [k]"; digest "level number and play fingerprint", never the shown key frame; schema 1 `{level, records}`;
  quality profile of three levels (the Core's `qualityTiers` equals the presenter's levels); each level certified
  directly from a table of its witness's `skipped` candidate, the whole generator only if that fails;
  `snapshot(time:)`) with `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismExperienceCoreTests.swift`
  (conformance; undo restores the digest; `frame.show` changes the snapshot but not the digest and refuses a missing key
  frame; snapshot round trip and refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismRendererPurityTests.swift` (200 seeded
  snapshots: tier, time, shown key frame and snapshot never change digest or verdict; the drawn shadows are the kernel's
  cast cells); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [ ] T-R02G1403-006 [US3] [US4] Create
  `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismExperience.swift`, `…Presenter.swift`,
  `…ClockworkScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce Flashing;
  the presenter declares `probes(_:)` — two backdrop corners, as the round-two X gates require — and its quality levels
  equal the Core's `qualityTiers`), `…Controls.swift` (labelled turn − and +, gear − and +, re-seat − and +, lamp − and
  +, key frame − and +, run, undo, redo, next level; gear 1 chosen when a level opens), and
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G14-QA-001 … 080) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismScenariosTests.swift` and
  `Packages/ExperiencesRound02/MoonlitMechanism/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate →
  `r02-g15.voxel-origami`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at time 0 at
  three tiers on 5 levels, at points at least 6 px from any other element: a cast cell's centre darker than the paper by
  0.25 in luminance; a gear's rim point with red above blue by 0.08; the first moves bar 0.1 from the paper; the backdrop
  within 0.05 of night; tier coordinates; fallback; resize and zero size; memory warning releases and the next frame
  rebuilds; Reduce Motion; a failure outlines the jammed teeth, forbidden cell or failing card; a won level brightens the
  wall; identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MoonlitMechanismExperienceTests`;
  `--name packages -- python3 scripts/check_experience_packages.py`; `--name catalog-search -- swift test --package-path
  Packages/VisualCore --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog
  search and stays ≤ 300 characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1403-007 Docs: `docs/architecture/moonlit-mechanism.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1403-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1403-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1403-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1403-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1403-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1403-006)
- [ ] T-R02G1403-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look is part of T-003 and T-004 from the start. Agents may
draft in isolated copies before 001 (new files only). Requirement coverage: FR-001, 002 → 003, 004; FR-003 → 002, 005;
FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 → 004, 006; FR-007 → 006; FR-008 → 006; FR-009 → 007 … 011.
