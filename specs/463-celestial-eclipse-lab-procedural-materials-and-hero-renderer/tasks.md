# Tasks: R02-G17-03 — Celestial Eclipse Lab: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G17-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G17-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_463;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1703-001 Baselines on the committed tree after R02-G17-02 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host and round02-1, -2, -3c, -3e, -3f exit 0; baseline-timing printed bounds above its asserts (process tree at background priority PRI 4, VisualCore unchanged), host scheduling, not code; rendering baseline is R02-G17-02's rendering runs (exit 0)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G17-02's
  rendering runs (exit 0)
- [ ] T-R02G1703-002 Edit `Packages/ExperiencesRound02/Package.swift` (`CelestialEclipseLabCore` gains VisualCoreScenes,
  VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; `CelestialEclipseLabExperience` and its tests
  with iOS-conditioned rendering dependencies join with their sources in T-006; the product); the renderer-purity and
  time scans of `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabInvariantTests.swift` read
  only its explicit `kernelFiles` list, so the presentation sources (snapshot, geometry, shaders, scenarios, adapter)
  are outside them; create `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSceneSnapshot.swift`
  (snapshot per data-model.md: bodies, phases, positions at the shown tick, eclipses under way at the shown tick with
  their classes, target, intervals, matched, failure, shownTick, horizon, chosenBody, stage, actionsLeft, budget,
  levelNumber, time; `CelestialEclipseLabTier` "level-0: spheres 24 × 16, 2 glow shells; level-1: 16 × 12, 1 shell;
  level-2: flat 20-sided discs, no glow; richest first"; `CelestialEclipseLabPalette` "ink #0B1530, inkTop #16224A,
  speck #C9D2FF, disc #E9E1CF, discShade #7A829A, orbit #33406E, fixedFrame #8A93B0, chosen #F2C14E, corona #F2C14E,
  coronaGlow #FFE7A3, crescentShadow #050A18, ember #C8553D, window #E8E2D0, matched #F2C14E, unwanted #C8553D,
  faintEvent #5A6488, playhead #FFE7A3, actionsLit #F2C14E, actionsUnlit #24305A, broken #E0533A, glow #FFF1D0");
  `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter CelestialEclipseLab`

## Phase 2: Stories 1 and 2 — the sky and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [ ] T-R02G1703-003 [P] [US1] Create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabShaders.swift` (sky and glow sources, GLSL ES
  3.00; layered body shading (core, limb darkening, rim light) from the normal; the crescent: the shadow lens (material
  16, a fan from its centroid) shaded in crescent shadow with a thin ember rim (the shared renderer binds only position,
  normal and uv, so the lens is geometry, not per-vertex mask attributes); signed-distance shading of rings, notches,
  frames, the chosen dashed ring, brackets, diamonds, crosses, the playhead and bars from per-vertex local coordinates;
  the backdrop gradient with sparse procedural specks under 5 % of its pixels; halos as thin emissive rings pulsed by
  `haloPulse(time: reduceMotion:)` (1 with Reduce Motion); the glow program shades halos, the chosen ring and lit marks;
  a won level flares the matched halos; uniform names; glow gain cap; palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabShaderSourceTests.swift` (version line,
  declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match, the pulse
  rule); agent A; `--name host-2`
- [ ] T-R02G1703-004 [P] [US1] Create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSceneGeometry.swift` (clarification Q1: w(v)
  = (v − m) · s with m the centre of the bounding box of every orbit position of every body widened by its radius in x
  and y and s = 1.5 / (e + 1) for its largest extent e; the backdrop quad; ring ribbons 0.012 wide through every orbit
  position with (index mod 6) + 1 notches at the body and a square frame for a fixed body; body spheres of radius r · s
  (segments by tier, flat 20-sided discs at level-2) carrying the circles of every nearer body in an eclipse under way
  at the shown tick; halos at the front body's rim for total and annular eclipses; the chosen dashed ring of radius r ·
  s + 0.04; the timeline strip at y = −1.15 from x = −0.9 to 0.9 over ticks 0 … horizon − 1, window brackets at y =
  −1.05 with the target index in notches, event marks (matched diamonds, the failing cross, faint after the last match)
  and the playhead at the shown tick; actions bars of `budget` at y = −1.35 from x = −0.9 to 0.9, each 1.8 / budget wide
  with a fifth as gap, 0.04 tall, lit for the actions left; painter's order back to front by camera distance, ties by
  kind (rings, bodies, halos, gauges) then index; a failure outlines its two bodies and marks the failing event (a
  horizon failure at the strip's end with the next target's bracket) in the broken colour; a won level lights every
  target mark without moving any position; `glowMesh` per tier (2, 1, 0 shells); camera from eye (0.3, 0.2, 3.4) to (0,
  −0.25, 0) fitted to x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 with a 5 % margin for aspect 0.4 … 2.5; `project`;
  the CPU reference points (body centres, the timeline centre, brackets, the playhead, the first actions bar) in paint
  order; fallback coloured parts) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabSceneGeometryTests.swift` (finite and
  bounded for extreme settings — 2 and 6 bodies, coordinates ±32, radius 8, horizon 8 and 96, budgets 1 and 24; every
  disc at every tick inside the view with margin at 7 aspects over the catalog's levels; the same positions at every
  tier; the bodies exactly at the kernel's positions for the shown tick; the crescent circles equal the kernel's
  eclipses under way; halos only for total and annular; gauges at 0, half and the budget; a won level in place; the glow
  mesh empty at level-2 and its shell counts per tier; the paint order sorted with the tie rule; each failure kind
  marked); agent B; `--name host-3`
- [ ] T-R02G1703-005 [P] [US2] Create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabExperienceCore.swift` (controls "orbit.phase
  [body, offset], clock.run, play.undo, play.redo, level.next, orbit.choose [body], clock.show [tick]"; `orbit.choose`
  refuses a body the level lacks and `clock.show` a tick outside 0 … horizon − 1; digest "level number and play
  fingerprint", never the choice or the shown tick; schema 1 `{level, records}`; the chosen body at opening the
  lowest-numbered movable body and the shown tick 0; quality profile of three levels (the Core's `qualityTiers` equals
  the presenter's levels); each level certified directly from a table of its witness's `skipped` candidate, the whole
  catalog only if that fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabExperienceCoreTests.swift` (conformance;
  undo restores the digest; choose and show change the snapshot but not the digest and refuse bad values; snapshot round
  trip and refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabRendererPurityTests.swift` (200 seeded
  snapshots: tier, time, choice, shown tick and snapshot never change digest or verdict; the drawn bodies are the
  kernel's positions at the shown tick); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [ ] T-R02G1703-006 [US3] [US4] Create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabExperience.swift`, `…Presenter.swift`,
  `…SkyScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; the halo pulse from presentation time;
  Reduce Motion and Reduce Flashing; the presenter declares `probes(_:)` — two backdrop corners, as the round-two X
  gates require — and its quality levels equal the Core's `qualityTiers`), `…Controls.swift` (labelled planet − and +,
  phase − and +, tick − and +, run, undo, redo, next level), and
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G17-QA-001 … 080) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabScenariosTests.swift` and
  `Packages/ExperiencesRound02/CelestialEclipseLab/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate →
  `r02-g18.apsides-workshop`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at the
  shown tick 0 at three tiers on 5 levels, at points at least 6 px from every element drawn after them: an uncovered
  body's centre brighter than the backdrop by 0.25 in luminance; the first actions bar with red above blue by 0.08; the
  timeline strip's centre 0.1 from the backdrop; the median of a 9 × 9 backdrop patch within 0.06 of the gradient; tier
  coordinates; fallback; resize and zero size; memory warning releases and the next frame rebuilds; Reduce Motion stops
  the pulse; a failure marks the failing event broken; a won level lights every target mark; identity); `--name sim-27
  -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing CelestialEclipseLabExperienceTests`; `--name packages -- python3
  scripts/check_experience_packages.py`; `--name catalog-search -- swift test --package-path Packages/VisualCore
  --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1703-007 Docs: `docs/architecture/celestial-eclipse-lab.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G1703-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1703-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1703-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1703-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1703-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1703-006)
- [ ] T-R02G1703-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look is part of T-003 and T-004 from the start. Agents may
draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage: FR-001, 002 → 003,
004; FR-003 → 002, 005; FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 → 004, 006; FR-007 → 006; FR-008 → 006;
FR-009 → 007 … 011.
