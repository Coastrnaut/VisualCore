# Tasks: R02-G21-03 — Binary Gardens: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_503;
tests stay short (< 10 s each). No {owner} tasks. Agents model their files on Mushroom Weather's as recorded at
R02-G20-03 (`git show a3269b5cc:<path>`, the R02-G20-03 record commit).

## Phase 1: Setup

- [X] T-R02G2103-001 Baselines on the committed tree after R02-G21-02 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit=0 (.autonomy/migration/checks/R02-G21-03.baseline-*.json); rendering baseline is R02-G21-02's runs
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (2 with BinaryGardens:
  `'MoonlitMechanism|AcousticConstellator|HarmonicBridges|BinaryGardens'`); the rendering baseline is R02-G21-02's
  rendering runs (exit 0)
- [X] T-R02G2103-002 Edit `Packages/ExperiencesRound02/Package.swift` (`BinaryGardensCore` gains VisualCoreScenes, — Verified 2026-11-27: host exit=0, 157 tests in 16 suites; Core dependencies added; invariant scans read the fixed ten-file list (count 10); snapshot, palette and tiers with BinaryGardensSceneSnapshotTests (.autonomy/migration/checks/R02-G21-03.host.json)
  VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; `BinaryGardensCoreTests` gains
  VisualCoreScenes, VisualCoreExperience and VisualCoreDiagnostics; `BinaryGardensExperience` (path
  `BinaryGardens/Experience`) and `BinaryGardensExperienceTests` (path `BinaryGardens/ExperienceTests`) with
  `condition: .when(platforms: [.iOS])` rendering dependencies (VisualCoreRendering, VisualCoreExperienceHost,
  VisualCoreUI) join with their sources in T-006; the `BinaryGardensExperience` library product); the kernel scans of
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensInvariantTests.swift` (no clock, floating point or
  run-time trigonometry; allowed imports) read a fixed list of the kernel's files — feature 501's five
  (`BinaryGardensError.swift`, `BinaryGardensLevel.swift`, `BinaryGardensPlay.swift`, `BinaryGardensPuzzle.swift`,
  `BinaryGardensSky.swift`) and feature 502's five in `Core/Content/` (`Content/BinaryGardensManifest.swift`, `Content/BinaryGardensDifficulty.swift`,
  `Content/BinaryGardensSolver.swift`, `Content/BinaryGardensGenerator.swift`, `Content/BinaryGardensWitness.swift`,
  read relative to `Core/`), and `#expect(sources.count == 5)` becomes `#expect(sources.count == 10)` — so the presentation
  sources (snapshot, shaders with `sin(`/`cos(`, geometry, adapter with `clock.show`, scenarios) stay outside them;
  create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneSnapshot.swift` (snapshot per data-model.md:
  ringRadii, luminosityLevels, maxTilt, phaseStep, lethalTolerance, worlds (`BinaryGardensSceneWorld`: radius, phase,
  speed, lethalLow, comfortLow, comfortHigh, lethalHigh, window, bloomLow, bloomHigh; positions, flux, shares
  `[tick − 1][star]` and bands at ticks 1 … 48, longestLethalRun, longestWindow (the report's `window`), windowStart, integral, bloom — "the
  kernel's integers, copied; positions at scale 2²⁰, flux and shares in milliflux"), arrangement, starPositions
  `[tick − 1][star]`, shownTick (1 … 48), fitScale k = 0.95 / R, failure, stage, actionsLeft, budget, levelNumber, time;
  "immutable; built by the adapter from the play (`init(play:shownTick:levelNumber:time:)`); never holds the kernel; a
  non-finite or negative time becomes 0; a shown tick outside 1 … 48 is clamped"; `isWon`, `band(_:)`,
  `share(_:star:)`, `starPoint(_:tick:)`, `worldPoint(_:tick:)`; `BinaryGardensTier` "level-0: 8 × 8 quads per face,
  12 corona rays, trails of 8 ticks, 8 motes, 2 glow shells; level-1: 5 × 5, 6 rays, 4 ticks, 4 motes, 1 shell;
  level-2: 3 × 3, no rays, trails, motes or glow", "richest first; `of(_:)` clamps"; `BinaryGardensPalette` "space
  #070815, spaceTop #151B3D, starfield #C8D2F0, ringIdle #2B3560, orbit #3A6B66, starOne #FF5A36, starTwo #A6DDFF, core
  #FFF4E8, world #7BE8BE, frost #DDF2FF, scorch #C2412A, flower #FFE6F2, pollen #FFE6F2, gaugePlate #1A2347, lethalLow
  #5C8DFF, dim #8FB8E0, comfortable #7BE8BE, bright #FFB27A, lethalHigh #FF4A3D, window #B8FFE0, marker #FFF4E8, tiltLit
  #A6DDFF, tiltUnlit #2B3560, actionsLit #FF7A4D, actionsUnlit #1E2648, broken #FF6B5E, glow #FFF9F0; `hex` = the catalog
  palette #070815, #FF5A36, #A6DDFF, #7BE8BE, #151B3D", "linear colours in 0 … 1 (byte / 255)") with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSceneSnapshotTests.swift` (27 colours and the hex
  list, tiers and `of(_:)` clamping, snapshot equal to the kernel's report at five shown ticks, won and failed plays,
  time and shown-tick clamping); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  BinaryGardens`

## Phase 2: Stories 1 and 2 — the system and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [X] T-R02G2103-003 [P] [US1] Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensShaders.swift` — Verified 2026-11-27: host-2 exit=0, BinaryGardensShaderSourceTests (18) (.autonomy/migration/checks/R02-G21-03.host-2.json)
  (system and glow sources, GLSL ES 3.00; `BinaryGardensMaterial` with contiguous codes from 0 per data-model.md —
  "valued materials (worlds: star 1 share / 64 000; trail: age; cells: height share) add 0.4 · value; +64 when broken";
  `encode` and `decode`; the still backdrop gradient with a fixed-hash starfield covering at most 2 % of the area; each
  world lit by both stars in their own colours by max(0, n · l_i) times its share (star 1's share / 64 000 in `a_uv.x`
  as the value, star 2's in `a_uv.y`, star positions at the shown tick in `u_star1`, `u_star2`) with a brightened
  sunrise band along each terminator (warm for star 1, cool for star 2) over an ambient floor of 0.35; shader-only
  seasonal banding from φ = asin(n.z) with feathered edges (lethal low frost caps |φ| ≥ 30°, dim caps |φ| ≥ 60°,
  comfortable petal dots from a fixed hash, bright a scorched belt |φ| ≤ 15°, lethal high a belt |φ| ≤ 40°);
  signed-distance shading of the flats (ring dashes, pips, cells crossed, hollow or solid, guide lines, window brackets
  solid or dashed, required tick, tick marker, bloom track, bracket and marker, actions bars, star discs with a white-hot
  core of half the radius, corona rays, motes, broken rings) from the quad-local coordinate and shape parameter in
  `a_normal` (material codes in uv: the shared renderer binds only position, normal and uv); coronas and motes moved by
  a time uniform (stopped under Reduce Motion); the glow program shades the stars and blooming worlds; a won level makes
  every world bloom; uniform names (system: `u_mvp`, `u_time`, `u_motion`, `u_won`, `u_star1`, `u_star2` = 9 slots;
  glow: `u_mvp`, `u_glowGain`, `u_glowLimit`, `u_won` = 7); glow gain cap; palette constants equal to the CPU's; the CPU
  twins `backdropColour`, `starfieldCoverage`, `worldShade`, `bandCoverage`, `flowerCoverage`, `shaderTime`, `motion`,
  `glowLimit`, `glowGain`) with `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensShaderSourceTests.swift`
  (version line, declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, contiguous material
  table and encode/decode round trip, palette constants match, starfield ≤ 2 %, banding latitudes, ambient floor, glow
  caps); agent A; `--name host-2`
- [X] T-R02G2103-004 [P] [US1] Create — Verified 2026-11-27: host-3 exit=0, BinaryGardensSceneGeometryTests (17) (.autonomy/migration/checks/R02-G21-03.host-3.json)
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSceneGeometry.swift` (clarification Q1: a kernel point p
  at k · p / 2²⁰ with k = 0.95 / R, R the largest of the level's ring radii and world radii, barycentre at the origin;
  the backdrop quad; the tilt dial of T_max + 1 pips from (−1.15, 1.08, 0) in steps of 0.05 (none when T_max = 0), pip
  τ filled; per ring radius a dashed 48-gon whose vertex i is (ρ·C[i]/1024, ρ·S[i]/1024·C[τ]/1024,
  ρ·S[i]/1024·S[τ]/1024) · k from `BinaryGardensSky.cosine` and `sine`, solid in a star's colour where it stands,
  alternating dash by dash when both share it; per world a 48-gon orbit (a·C[i]/1024, a·S[i]/1024, 0) · k, so every body
  is exactly a vertex of its orbit; trails at the kernel's positions of the 8 or 4 ticks before the shown tick, cyclic
  (((t − 1 − a) mod 48) + 1), fading with age; `cubeSphere(faceQuads:)` (six faces of n × n quads normalised onto the
  unit sphere, faces emitted far-first from the fixed eye) of radius 0.07 at the world's position at the shown tick, its
  band as the material, with j + 1 pips; star discs facing the eye of radius 0.05 + 0.012 · (luminosity index), core
  half that, corona rays per tier and one pip per luminosity level filled up to the current one; gauge row j at y = −1.2
  − 0.1 · j: plate x −0.95 … 1.22, cell t at x −0.9 + (t − 0.5) · 1.8/48, width 1.8/48 · 0.8, height 0.01 + 0.06 ·
  min(1, F/λ_hi), guide lines at the heights of c_lo and c_hi, window bracket from windowStart over longestWindow cells
  (two pieces when it wraps past tick 48), required tick at W cells, solid when longestWindow ≥ W, tick marker above
  column t, bloom meter x 0.97 … 1.2 over 0 … max(1, 2 · B_hi), bracket B_lo … B_hi, marker at min(I, 2 · B_hi); actions
  bars "y = −1.2 − 0.1 · worlds − 0.03; `budget` bars, each 1.8 / budget wide with a fifth as gap, 0.035 tall, the first
  `actionsLeft` lit"; motes per tier on fixed loops around comfortable worlds; painter's order with depth testing off and
  no face culling — "by kind, the bodies sorted back to front by eye distance (ties: worlds before stars, then index)"
  (`drawsBefore`, `paintOrder`); failures marked in the broken colour per clarification Q4 (frozen or scorched: a broken
  ring around the named world and its gauge cell at column ((tick − 1) mod 48) + 1; unstable: the window bracket, or the
  required-length tick W alone when window 0, start 0; wilted or bleached: the bloom marker); a won level blooms every
  world without moving any position; `glowMesh` per tier (2, 1, 0 shells); camera from eye (0, −2.0, 3.2) to (0, −0.35,
  0) fitted to x −1.3 … 1.3, y −1.85 … 1.15, z −0.85 … 0.85 with a 5 % margin for aspect 0.4 … 2.5; `project`; the CPU
  reference points "the barycentre, every world centre, both star centres, the first gauge plate's left margin (−0.925,
  −1.2, 0), the first actions bar"; `colour(of:won:)`; fallback coloured parts (`systemPart`)) with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSceneGeometryTests.swift` (finite and bounded for
  extreme settings — 1 and 5 worlds, 2 and 8 rings, radii 1 and 60 units, tilt 0 and 6, a star and a world at the same
  point, a world held still, retrograde worlds, flux 0 and 128 000 milliflux, budgets 1 and 24; every body on a vertex
  of its drawn orbit; every element inside the view with margin at 7 aspects over the catalog's levels; the same
  positions at every tier; cube-sphere vertices on the unit sphere and its face counts per tier; cell heights, window
  brackets (wrapping and empty) and bloom markers from the kernel's values only; trail ticks cyclic; a won level in
  place; the glow mesh empty at level-2 and its shell counts per tier; each failure kind marked; shader stream
  encoding); agent B; `--name host-3`
- [X] T-R02G2103-005 [P] [US2] Create — Verified 2026-11-27: host-4 exit=0, BinaryGardensExperienceCoreTests (15) and RendererPurityTests (200 seeded snapshots) (.autonomy/migration/checks/R02-G21-03.host-4.json)
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensExperienceCore.swift` (controls "`star.ring [star,
  index]`, `star.phase [star, step]`, `star.luminosity [star, index]`, `orbit.tilt [step]`, `light.run`, `play.undo`,
  `play.redo`, `level.next`, `clock.show [tick]`; declared ranges star 0 … 1, ring index 0 … 7, phase 0 … 47,
  luminosity index 0 … 3, tilt 0 … 6, tick 0 … 60"; "whole numbers only (`r02-g21.not-whole`); kernel refusals pass
  through with their codes (`r02-g21.action`, `.budget`, `.stage`); `clock.show` refuses 0 and 49 … 60 with
  `r02-g21.tick` and never touches the kernel"; digest "domain `r02-g21.binary-gardens.v1`, level number, play
  fingerprint (never the record history, shown tick or tier, so undo restores the earlier digest)"; "`==` on level
  number and play; snapshot schema 1 `{level, records}` (sorted keys)"; `BinaryGardensRestoreRefusal`; the shown tick 48
  at opening, kept across ring, phase, luminosity, tilt, run, undo and redo, back to 48 at an opening, `level.next`,
  reset and restore; quality profile of three levels per research R14 (the Core's `qualityTiers` equals the presenter's
  levels); level (seed mod 100) + 1, each level certified directly from a table of its witness's `skipped` candidate
  (`certifiedCandidates`), the whole catalog only if that fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensExperienceCoreTests.swift` (conformance; undo
  restores the digest; show changes the snapshot but not the digest and refuses bad values with `r02-g21.tick`;
  fractional values refused with `r02-g21.not-whole`; snapshot round trip and refusals; the candidate table equals the
  witnesses' `skipped`) and `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensRendererPurityTests.swift`
  (200 seeded snapshots: tier, time, shown tick and snapshot never change digest or verdict; drawn positions, shares,
  bands, windows and integrals are the kernel's); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [X] T-R02G2103-006 [US3] [US4] Create — Verified 2026-11-27: scenarios, packages, catalog-search exit=0; sim-27-2 exit=0, 30 tests in 4 suites (first attempt sim-27 failed to compile a multi-line switch expression, fixed with explicit returns) (.autonomy/migration/checks/R02-G21-03.{scenarios,packages,catalog-search,sim-27-2}.json); registered as a candidate, synthetic candidate now r02-g22.mycelium-architect
  `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensExperience.swift`, `…Presenter.swift`,
  `…SystemScene.swift` (GL scene with `ShaderMeshRenderer`; fallback through `MeshRenderer` with `fallbackReason`; tier
  log with reason ("first frame", "quality controller changed the tier"); Reduce Motion and Reduce Flashing; the
  presenter declares `probes(_:)` — two backdrop corners, as the round-two X gates require — and its quality levels
  equal the Core's `qualityTiers`; experience sources in `#if os(iOS)`), `…Controls.swift` (labelled star picker, ring
  − and +, phase − and + by the phase step, luminosity − and +, tilt − and +, tick − and +, run, undo, redo, next
  level), and `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensScenarios.swift` (under `#if DEBUG ||
  VISUALCORE_AUTOMATION`: standard scenarios, full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G21-QA-001 …
  080, manifest seed 0) with `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensScenariosTests.swift`
  and `Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json` (generated; the committed manifest equals the
  Swift one; `--name scenarios -- swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`);
  register the candidate (`Catalog/registrations.json` with `r02-g21.binary-gardens`, tiers `level-0` … `level-2`, the
  palette, capabilities ≤ 40 characters, summary ≤ 300 characters, `content`: `levels` 100 and `catalog_sha256` = `BinaryGardensCatalogTests.pinnedDigest`, the scenario manifest, no permissions, `available: false`; `python3 scripts/build_catalog.py`
  regenerates `Catalog/experiences.json` and
  `Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/{registrations,experiences}.json`;
  `Packages/VisualCore/Tests/VisualCoreExperienceTests/RealCatalogTests.swift` lists the new registration;
  `Apps/VisualCore/App/ExperienceRegistry.swift` (`ExperienceRegistry.candidates`, opening seed 0); `project.yml` adds
  the `BinaryGardensCore` and `BinaryGardensExperience` products + `xcodegen generate`;
  `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate → `r02-g22.mycelium-architect`;
  `scripts/test_scripts.py` lists the two products); agent D writes
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/` (`BinaryGardensTestSupport.swift`,
  `BinaryGardensRenderTests.swift`, `BinaryGardensTierTests.swift`, `BinaryGardensFallbackTests.swift`,
  `BinaryGardensExperienceIdentityTests.swift`: render vs CPU reference at 1,152 × 768 at shown tick 24 at three tiers
  on levels 1, 21, 41, 61, 81, at points at least 6 px from every element drawn after them: each world's centre
  brighter than the backdrop by 0.15 in luminance, at least one world checked; each star's centre brighter than the
  backdrop by 0.4, at least one star checked; the first actions bar (lit) with red above blue by 0.08; the first gauge
  plate's left margin 0.05 from the backdrop; the median of a 9 × 9 lower-corner patch within 0.06 of the gradient; tier
  coordinates; fallback (a forced shader failure leaves the digest and verdict unchanged); resize and zero size; memory warning releases and the next frame rebuilds; Reduce Motion keeps
  the frame still; a failure marks the failing element broken; a won level blooms every world; identity); `--name
  sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BinaryGardensExperienceTests`; `--name
  packages -- python3 scripts/check_experience_packages.py`; `--name catalog-search -- swift test --package-path
  Packages/VisualCore --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog
  search and stays ≤ 300 characters)

## Phase 4: Regression, documentation and close

- [X] T-R02G2103-007 Docs: `docs/architecture/binary-gardens.md` (renderer and experience), — Verified 2026-11-27: docs (architecture renderer and experience, package README, automatedtesting) and round02-host-1, -2, -3c, -3e, -3f exit=0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2` (filter
  `'MoonlitMechanism|AcousticConstellator|HarmonicBridges|BinaryGardens'`), `-3c`, `-3e`, `-3f`
- [X] T-R02G2103-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-27: rendering-27, rendering-26, experiences, host-full, app-unit exit=0 (.autonomy/migration/checks/R02-G21-03.{rendering-27,rendering-26,experiences,host-full,app-unit}.json)
  `--name host-full`, `--name app-unit` (`python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`: the candidate opens; the synthetic candidate is `r02-g22.mycelium-architect`)
- [X] T-R02G2103-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-27: reference-1 exit=0 (.autonomy/migration/checks/R02-G21-03.reference-1.json)
- [X] T-R02G2103-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-27: reference-2 exit=0 (.autonomy/migration/checks/R02-G21-03.reference-2.json)
- [X] T-R02G2103-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-27: script-tests exit=0 (.autonomy/migration/checks/R02-G21-03.script-tests.json)
- [ ] T-R02G2103-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G2103-006)
- [ ] T-R02G2103-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then
  `python3 scripts/build_catalog.py --check` last, seal and record; README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level bloom is part of T-003 and T-004 from the start. Agents may
draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage: FR-001, 002 → 003,
004; FR-003 → 002, 005; FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 → 004, 006; FR-007 → 006; FR-008 → 006;
FR-009 → 002, 007 … 011; FR-010 → 003, 004, 006.

## Phase 5: Convergence

- [ ] T-R02G2103-014 State in `specs/503-binary-gardens-procedural-materials-and-hero-renderer/spec.md` (clarification Q1)
  and `research.md` that each star's light reaches a world through the logarithmic response
  `BinaryGardensShaders.lightResponse(share:)` (log2, 1 at 1 024 milliflux) of the share the uv stream carries
  (share / 64 000), since a linear share leaves catalog worlds black, per Clarifications Q1 (contradicts)
- [ ] T-R02G2103-015 State in `spec.md` (clarification Q3) that in the unlit fallback a star's frame check is its flat
  colour within 0.1 (the +0.4 margin applies to the shader path), per SC-R02G2103-001 (partial)
- [ ] T-R02G2103-016 Record in `research.md` that failure marks are drawn on a failed play only (as feature 493), that the
  hero tick is the earliest tick with the most comfortable worlds after the certified plan, and that the gauge plate's
  quad spans u = ±1 to stay inside the fitted box, per plan: research (partial)
