# Tasks: R02-G16-03 — Starlit Cartouche: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G16-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_453;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1603-001 Baselines on the committed tree after R02-G16-02 is recorded: `--name baseline-host`, `--name — Verified 2026-11-24: baseline-host, baseline-timing, baseline-round02-1..3 exit 0 (.autonomy/migration/checks/R02-G16-03.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1 … 3` (the three round-two filters of feature 446); the rendering
  baseline is R02-G16-02's rendering runs (exit 0)
- [X] T-R02G1603-002 Edit `Packages/ExperiencesRound02/Package.swift` (`StarlitCartoucheCore` gains VisualCoreScenes, — Verified 2026-11-24: host exit 0 (.autonomy/migration/checks/R02-G16-03.host.json); Package.swift Core deps, StarlitCartoucheSceneSnapshot.swift (palette, tiers, snapshot with failedLeg and defaultChoice); invariant scans already read only kernelFiles
  VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; `StarlitCartoucheExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); the renderer-purity and time
  scans of `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheInvariantTests.swift` read only its
  explicit `kernelFiles` list, so the presentation sources (snapshot, geometry, shaders, scenarios, adapter) are
  already outside them; create
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSceneSnapshot.swift` (snapshot per data-model.md:
  stars, positions at the beat, corridors, hazards and active flags, legs with departure and arrival positions, drawn,
  symbol, star, beat, beacon, deadline, chosenStar, chosenWait, report, stage, failure, failedLeg (recomputed through
  the chart from the last record's action), actionsLeft, budget, levelNumber, time; `StarlitCartoucheTier` "level-0:
  spheres 16 × 12, 3 trail ghosts, 2 glow shells; level-1: 12 × 8, 1 ghost, 1 shell; level-2: flat 12-sided discs, no
  ghosts, no glow; richest first"; `StarlitCartouchePalette` "night #0A1240, nightTop #141E5C, speck #C9D2FF, pearl
  #F2EEE6, pearlShade #B8C0D8, corridor #3A4478, symbolDash #C9CCE0, trail #F5B83D, trailGlow #FFE3A0, ship #2F6BFF,
  shipGlow #8FB0FF, beacon #F2EEE6, chosen #2F6BFF, hazardActive #FF5A5F, hazardIdle #5A3A58, actionsLit #F5B83D,
  actionsUnlit #283058, beatTrack #8FB0FF, waitLit #2F6BFF, waitUnlit #283058, broken #FF6B4A, glow #FFF4E0"); `--name
  host -- swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartouche`

## Phase 2: Stories 1 and 2 — the chart and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [X] T-R02G1603-003 [P] [US1] Create `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheShaders.swift` — Verified 2026-11-24: host-2 exit 0 (.autonomy/migration/checks/R02-G16-03.host-2.json); chart and glow GLSL ES 3.00, 22 material codes, palette constants, firmament angle rule, glow gain/limit; 17 shader-source tests (glslangValidator absent, compile check skipped; real compile proven in the sim run of T-006)
  (chart and glow sources, GLSL ES 3.00; layered star shading (core, limb, corona) from the normal; signed-distance
  shading of dashes, stripes, notches, rings, the ship arrow, the cartouche grid and strokes, bars, track and pips from
  per-vertex local coordinates; the firmament gradient with sparse procedural specks under 5 % of its pixels, turned by
  an angle uniform (0.02 rad/s, 0 with Reduce Motion); trail ghosts with falling alpha; the glow program shades stars,
  the ship and lit trails; a won level flares the trails and seals the cartouche; uniform names; glow gain cap; palette
  constants equal to the CPU's) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheShaderSourceTests.swift` (version line,
  declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match, the angle
  rule); agent A; `--name host-2`
- [X] T-R02G1603-004 [P] [US1] Create — Verified 2026-11-24: host-3 exit 0 (.autonomy/migration/checks/R02-G16-03.host-3.json); scene geometry (mapping, chart meshes per shader vertex contract, camera with 6 % fit, CPU reference, paint order, failure marks, glow per tier, fallback parts), 12 geometry tests
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSceneGeometry.swift` (clarification Q1: w(v) =
  (v − m) · s with m the centre of the bounding box of every orbit position of every star and s = 1.5 / (e + 1) for its
  largest extent e; the firmament quad; corridor ribbons 0.02 wide between current positions, undrawn symbol corridors
  dashed; hazard tubes 0.06 wide, striped, active when from ≤ beat ≤ to; trail ribbons 0.05 wide from the departure to
  the arrival position of each flown leg, with ghosts by tier; star spheres of radius 0.07 (segments by tier, flat
  12-sided discs at level-2) with rings of (index mod 6) + 1 notches; the ship arrow of length 0.14 along its last trail
  (+x before the first leg), placed along the last trail by `glide` 0 … 1; the beacon ring of radius 0.12 and the chosen
  dashed ring of radius 0.1; the cartouche, a 5 × 5 grid 0.5 wide centred at (−0.5, −1.2) with each symbol corridor a
  line between its stars' glyph points, dashed until drawn; actions bars of `budget` at y = −1.05 from x = 0.0 to 0.9,
  each 0.9 / budget wide with a fifth as gap, 0.04 tall, lit for the actions left; the beat track at y = −1.2 filled to
  beat / deadline; 9 wait pips at y = −1.35 lit up to the chosen wait; painter's order back to front by camera
  distance, ties by kind (corridors, hazards, trails, stars, ship and beacon, gauges) then index; a failure draws the
  failed leg in the broken colour and marks the star, hazard, stray stroke, beat track or actions bars; a won level
  lights every symbol trail without moving any position; `glowMesh` per tier (2, 1, 0 shells); camera from eye
  (1.2, 1.0, 2.8) to (0, −0.2, 0) fitted to x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 with a 5 % margin for aspect
  0.4 … 2.5; `project`; the CPU reference points (star centres, the ship, trail midpoints, the cartouche centre, the
  first actions bar) in paint order; fallback coloured parts) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheSceneGeometryTests.swift` (finite and bounded
  for extreme settings — 4 and 12 stars, orbit coordinates ±8, 24 corridors, 8 hazards, budgets 1 and 24, deadline 64;
  every star at every beat 0 … 64, the cartouche, bars, track and pips inside the view with margin at 7 aspects over
  the catalog's levels; the same positions at every tier; the stars exactly at the kernel's positions for the beat;
  trails at the legs' departure and arrival positions; gauges at 0, half and the budget; a won level brighter and in
  place; the glow mesh empty at level-2 and its shell counts per tier; only sphere detail, ghosts and glow differ
  between tiers; the paint order sorted with the tie rule; each failure kind marked); agent B; `--name host-3`
- [X] T-R02G1603-005 [P] [US2] Create — Verified 2026-11-24: host-4 exit 0 (.autonomy/migration/checks/R02-G16-03.host-4.json); adapter (5 controls, refusal codes r02-g16.not-whole and r02-g16.choice, digest level+fingerprint, schema 1, certified table), 16 adapter and purity tests incl. 200 seeded snapshots
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheExperienceCore.swift` (controls "route.fly [star,
  wait], play.undo, play.redo, level.next, route.choose [star, wait]"; `route.choose` refuses a star the level lacks,
  the ship's own star or a wait outside 0 … 8; digest "level number and play fingerprint", never the choice; schema 1
  `{level, records}`; the choice at opening and after each leg is the other end of the lowest-index corridor from the
  ship's star with wait 0; quality profile of three levels (the Core's `qualityTiers` equals the presenter's levels);
  each level certified directly from a table of its witness's `skipped` candidate, the whole generator only if that
  fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheExperienceCoreTests.swift` (conformance; undo
  restores the digest; `route.choose` changes the snapshot but not the digest and refuses bad choices; snapshot round
  trip and refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheRendererPurityTests.swift` (200 seeded
  snapshots: tier, time, choice and snapshot never change digest or verdict; the drawn stars are the kernel's positions
  at the beat); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [ ] T-R02G1603-006 [US3] [US4] Create
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheExperience.swift`, `…Presenter.swift`,
  `…ChartScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; the firmament angle and the ship's glide
  from presentation time; Reduce Motion and Reduce Flashing; the presenter declares `probes(_:)` — two backdrop corners,
  as the round-two X gates require — and its quality levels equal the Core's `qualityTiers`), `…Controls.swift`
  (labelled destination − and +, wait − and +, fly, undo, redo, next level), and
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G16-QA-001 … 080) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheScenariosTests.swift` and
  `Packages/ExperiencesRound02/StarlitCartouche/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate →
  `r02-g17.celestial-eclipse-lab`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at time 0 at
  three tiers on 5 levels, at points at least 6 px from every element drawn after them: a star's centre brighter than
  the backdrop by 0.25 in luminance; the ship's centre with blue above red by 0.08; a trail midpoint with red above blue
  by 0.08; the first actions bar 0.1 from the backdrop; the median of a 9 × 9 backdrop patch within 0.06 of the
  gradient; tier coordinates; fallback; resize and zero size; memory warning releases and the next frame rebuilds;
  Reduce Motion stops the firmament and the glide; a failure draws the failed leg broken; a won level lights every
  symbol trail; identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  StarlitCartoucheExperienceTests`; `--name packages -- python3 scripts/check_experience_packages.py`; `--name
  catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1603-007 Docs: `docs/architecture/starlit-cartouche.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 … 3`
- [ ] T-R02G1603-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1603-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1603-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1603-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1603-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1603-006)
- [ ] T-R02G1603-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look is part of T-003 and T-004 from the start. Agents may
draft in isolated copies before 001 (new files only). Requirement coverage: FR-001, 002 → 003, 004; FR-003 → 002, 005;
FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 → 004, 006; FR-007 → 006; FR-008 → 006; FR-009 → 007 … 011.
