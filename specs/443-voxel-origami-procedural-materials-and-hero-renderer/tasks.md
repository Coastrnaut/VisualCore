# Tasks: R02-G15-03 — Voxel Origami: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G15-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G15-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_443;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1503-001 Baselines on the committed tree after R02-G15-02 is recorded: `--name baseline-host`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree after R02-G15-02's record
  baseline-timing`, `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering
  baseline is R02-G15-02's rendering runs (exit 0)
- [X] T-R02G1503-002 Edit `Packages/ExperiencesRound02/Package.swift` (`VoxelOrigamiCore` gains VisualCoreScenes, — Verified 2026-11-24: 2026-11-24: Package.swift deps added, VoxelOrigamiSceneSnapshot.swift (palette, tiers, snapshot); the invariant scans read only the explicit kernelFiles list, so presentation sources are already skipped; host exit 0
  VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; `VoxelOrigamiExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); make the renderer-purity and
  time scans of `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiInvariantTests.swift` skip the
  presentation sources (snapshot, geometry, shaders, scenarios, adapter), which use Doubles and other imports; create
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiSceneSnapshot.swift` (snapshot per data-model.md: cubes,
  cells, orientations, turns, turnable, chosenHinge, target at the best alignment, report, stage, failure, actionsLeft,
  budget, levelNumber, time; `VoxelOrigamiTier` "level-0: 2 bevel steps, edges 0.06 s, 2 glow shells; level-1: 1 step,
  0.05 s, 1 shell; level-2: no bevel, 0.04 s, none; richest first"; `VoxelOrigamiPalette` "night #0B0D16, ivory #EDE8DC,
  ivoryShade #B9B2A3, target #2EE6D6, targetGlow #8FF5EC, hinge #7F7A70, hingeChosen #FF3C8C, glyphSolid #2EE6D6,
  glyphHollow #4A4E5C, dots #3A3D48, coveredLit #FF3C8C, coveredUnlit #2A2D3A, movesLit #2EE6D6, movesUnlit #2A2D3A,
  broken #FF6B4A, glow #FFF4E0"); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  VoxelOrigami`

## Phase 2: Stories 1 and 2 — the voxels and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [X] T-R02G1503-003 [P] [US1] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiShaders.swift` (voxel — Verified 2026-11-24: 2026-11-24: VoxelOrigamiShaders.swift (voxel and glow GLSL ES 3.00, material codes 0…13, palette constants, glow gain and limit) and 12 shader-source tests; lead reran host-2 exit 0
  and glow sources, GLSL ES 3.00; signed-distance shading of cube edges, bevels, inner glyphs, dots, hinge bars and
  stripes, target wireframe edges and gauges from per-vertex local coordinates; frosted faceted shading of the cubes
  from the face normal; the glow program shades lit cubes and the target outline; a won level flares the target; uniform
  names; glow gain cap; palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiShaderSourceTests.swift` (version line, declared
  uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match); agent A; `--name
  host-2`
- [X] T-R02G1503-004 [P] [US1] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiSceneGeometry.swift` — Verified 2026-11-24: 2026-11-24: VoxelOrigamiSceneGeometry.swift (mapping, chamfered cubes, target wireframe, hinge bars, gauges, paint order, winding for back-face culling, glow shells, camera with a 6 % fit margin per side so every element keeps at least the 5 % margin, fallback parts) with 13 geometry tests; lead reran host-3 exit 0
  (clarification Q1: w(c) = (c − m) · s with m the centre of the bounding box of the occupied cells and the target cells
  at the best allowed alignment and s = 1.5 / (e + 1) for its largest extent e; the night backdrop; one wireframe cube
  of side 0.96 s per target cell with edges of the tier's width; chamfered cubes of side 0.9 s at w(cell) turned by their
  orientation, bevel steps by tier, an inner glyph (solid when the cube's cell is a target cell, hollow otherwise) and
  (index mod 6) + 1 dots on the +z face; hinge bars on the face between parent and cube, 0.6 s long along the axis and
  0.12 s wide, the chosen hinge striped; covered pips at y = −1.05 from x = −0.8 to 0.8 lit for the covered count; moves
  bars of `budget` at y = −1.2 from x = −0.9 to 0.9, each 1.8 / budget wide with a fifth as gap, 0.04 tall, lit for the
  actions left; painter's order back to front by camera distance, ties by kind (target outline, cubes, hinge marks,
  gauges) then index; a failure outlines the moving cube and the cube in its way in the broken colour and marks their
  cell; a won level lights every cube without moving any position; `glowMesh` per tier (2, 1, 0 shells); camera from
  eye (1.4, 1.1, 2.6) to (0, −0.1, 0) fitted to x −0.95 … 0.95, y −1.25 … 0.95, z −0.95 … 0.95 with a 5 % margin for
  aspect 0.4 … 2.5; `project`; the CPU reference points (cube centres, hinge centres, the first pip and moves bar) in
  paint order; fallback coloured parts) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiSceneGeometryTests.swift` (finite and bounded for
  extreme settings — 4 and 12 cubes, straight and folded chains, budgets 1 and 40; every cube, hinge, pip and bar inside
  the view with margin at 7 aspects over the catalog's levels; the same positions at every tier; the cubes exactly at
  the kernel's cells; the target at the covered count's alignment; gauges at 0, half and the budget; a won level
  brighter and in place; the glow mesh empty at level-2 and its shell counts per tier; only bevels, edge widths and glow
  differ between tiers; the paint order sorted with the tie rule); agent B; `--name host-3`
- [X] T-R02G1503-005 [P] [US2] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiExperienceCore.swift` — Verified 2026-11-24: 2026-11-24: VoxelOrigamiExperienceCore.swift (5 controls, digest level+fingerprint, schema 1, three-level profile, certified candidate table) with 14 adapter tests and 2 purity tests (200 seeded snapshots); lead reran host-4 exit 0 and the stored-witness table test passed against the real docs
  (controls "hinge.turn [h, ±1], play.undo, play.redo, level.next, hinge.choose [h]"; digest "level number and play
  fingerprint", never the chosen hinge; schema 1 `{level, records}`; quality profile of three levels (the Core's
  `qualityTiers` equals the presenter's levels); each level certified directly from a table of its witness's `skipped`
  candidate, the whole generator only if that fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiExperienceCoreTests.swift` (conformance; undo restores
  the digest; `hinge.choose` changes the snapshot but not the digest and refuses a missing hinge; snapshot round trip
  and refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiRendererPurityTests.swift` (200 seeded snapshots: tier,
  time, chosen hinge and snapshot never change digest or verdict; the drawn cubes are the kernel's cells); agent C;
  `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [X] T-R02G1503-006 [US3] [US4] Create `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiExperience.swift`, — Verified 2026-11-24: 2026-11-24: experience target (experience, presenter with probes and tier log, voxel scene, controls), scenarios (94: 80 QA rows) and manifest, candidate registration (registrations, catalog, registry, project.yml, AppModelTests candidate r02-g16, script list); hinge marks lifted 0.55 s toward the eye so the nearer cube no longer hides them; won level lifts cube faces in the shader too; sim-27 22 tests exit 0, packages-2 exit 0 (first packages run failed before the test target existed), catalog-search exit 0, host-5 exit 0
  `…Presenter.swift`, `…VoxelScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and
  Reduce Flashing; the presenter declares `probes(_:)` — two backdrop corners, as the round-two X gates require — and its
  quality levels equal the Core's `qualityTiers`), `…Controls.swift` (labelled hinge − and +, turn − and +, undo, redo,
  next level; the first hinge that can turn chosen when a level opens), and
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiScenarios.swift` (standard scenarios, full-playthrough,
  hero, fixtures, 80 acceptance scenarios R2-G15-QA-001 … 080) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiScenariosTests.swift` and
  `Packages/ExperiencesRound02/VoxelOrigami/scenario-manifest.json`; register the candidate (`Catalog/registrations.json`
  with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` + `xcodegen
  generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate → `r02-g16.starlit-cartouche`,
  `scripts/test_scripts.py`); agent D writes `Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/` (render vs CPU
  reference at 1,152 × 768 at time 0 at three tiers on 5 levels, at points at least 6 px from every element drawn after
  them: a cube's centre brighter than the backdrop by 0.25 in luminance; the chosen hinge's centre with red above blue
  by 0.08; the first moves bar 0.1 from the backdrop; the backdrop within 0.05 of night; tier coordinates; fallback;
  resize and zero size; memory warning releases and the next frame rebuilds; Reduce Motion; a failure outlines the
  moving cube and the cube in its way; a won level lights every cube; identity); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing VoxelOrigamiExperienceTests`; `--name packages -- python3
  scripts/check_experience_packages.py`; `--name catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1503-007 Docs: `docs/architecture/voxel-origami.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1503-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1503-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1503-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1503-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1503-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1503-006)
- [ ] T-R02G1503-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look is part of T-003 and T-004 from the start. Agents may
draft in isolated copies before 001 (new files only). Requirement coverage: FR-001, 002 → 003, 004; FR-003 → 002, 005;
FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 → 004, 006; FR-007 → 006; FR-008 → 006; FR-009 → 007 … 011.
