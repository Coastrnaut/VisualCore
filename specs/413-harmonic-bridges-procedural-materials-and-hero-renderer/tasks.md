# Tasks: R02-G12-03 — Harmonic Bridges: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G12-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G12-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_413;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1203-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree; rendering baseline is R02-G12-02's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G12-02's
  rendering runs (exit 0)
- [X] T-R02G1203-002 Edit `Packages/ExperiencesRound02/Package.swift` (`HarmonicBridgesExperience` and its tests with — Verified 2026-11-23: host exit 0 (all Harmonic Bridges tests); HarmonicBridgesSceneSnapshot (islands, strings, pegs, the kernel's report, modes and strengths per step and string, threshold, start, goal, stage, failure, actions left, budget, level, time; shownStep cycling every 1.2 s, restingStep, failure text), HarmonicBridgesTier (level-0 motion, 2 wave shells, 2 glow shells; level-1 motion, 1 glow shell; level-2 at rest) and HarmonicBridgesPalette incl. brokenOutline; the invariant scan reads a fixed list of kernel files, so presentation sources are excluded without a change; the Core already links every product the renderer needs
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); make the renderer-purity scan
  of `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesInvariantTests.swift` skip the presentation
  sources (snapshot, geometry, shaders, scenarios, adapter), which use Doubles; create
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSceneSnapshot.swift` (snapshot per data-model.md:
  islands, strings, pegs, report, modes and strengths per step and string, threshold, start, goal, stage, failure,
  actionsLeft, budget, levelNumber, time, `shownStep` "cycles every 1.2 s while playing; 0 at time 0";
  `HarmonicBridgesTier` "level-0: motion, 2 wave shells, 2 glow shells; level-1: motion, no shells, 1 glow shell;
  level-2: at rest, none; richest first"; `HarmonicBridgesPalette` "ground #07060C, islandFace #7A4A2E, islandEdge
  #E0A070, string #C88A5A, membrane #4FD8E8, markFilled #B8F4FF, markHollow #7A6A9C, start #F2D2A8, goal #A894FF, glow
  #8FF4FF, shell #6FE0F0, pip #4FD8E8, pipUnlit #3A3348, gaugeLit #E0A070, gaugeUnlit #2A2433"); `--name host -- swift
  test --package-path Packages/ExperiencesRound02 --filter HarmonicBridges`

## Phase 2: Stories 1 and 2 — the bridges and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [X] T-R02G1203-003 [P] [US1] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesShaders.swift` — Verified 2026-11-23: Verified 2026-11-23: host-2 exit 0 (HarmonicBridgesShaderSourceTests 16: material codes 0…15, attributes and uniforms of both programs within 16 vec4, no samplers, loops bounded, the wave 0.01·w per mode decoded from the packed modes, shell positions, 16 palette constants equal to the CPU palette incl. broken outline #FF6B4A); agent A's sources, rewritten to agent B's stream contract, retested by the lead
  (bridge and glow sources, GLSL ES 3.00; signed-distance shading of membranes, marks, rings and edge strips from
  per-vertex local coordinates; the presentation wave Σ 0.03 · w · sin(nπu) · cos(2π n t / 1.6) of up to 3 modes driven
  by `u_time`, zero at level-2 and under Reduce Motion; wave shells expanding from radius 0 to 0.15 over 1.6 s; a won
  level lifts membranes and reached-island glow; uniform names; glow gain cap; palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesShaderSourceTests.swift` (version line, declared
  uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match); agent A; `--name
  host-2`
- [X] T-R02G1203-004 [P] [US1] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSceneGeometry.swift` — Verified 2026-11-23: Verified 2026-11-23: host-3 exit 0 (HarmonicBridgesSceneGeometryTests 13: finite and bounded for 2/8 islands, 1/12 strings, all/no bridges, budgets 1/60, 4 steps; island tops, membrane check points, gauge bars and pips in view with margin at 7 aspects; same positions at every tier; marks filled exactly where the kernel's swing reaches the threshold; gauge at 0, half and budget; a won level brighter and in place); agent B's geometry retested by the lead
  (clarification Q1: island (gx, gy) at X = (gx − 7.5) · 0.12, Z = (gy − 4.5) · 0.12; ground at y = −0.01 over x −1.1 …
  1.1, z −0.8 … 1.1; hexagonal island prisms radius 0.07, height 0.1, with top edge strips 0.008 thick; start ring radius
  0.1 line 0.012 at y = 0.005; goal four-pointed star radius 0.1; strings as strips 0.012 wide at y = 0.1 with 24
  segments; membranes 0.05 wide beneath strings that are bridges in the shown step; five sample marks 0.02 wide at
  y = 0.11 — filled squares at or above the threshold, hollow rings below; reached-island glow rings; pips 0.06 wide
  spread from x = −0.3 to 0.3 at z = 0.8 (filled, outlined, a cross on a broken step); gauge of `budget` bars at z = 0.95
  from x = −0.9 to 0.9, each 1.8 / budget wide with a fifth as gap, 0.05 deep, lit for the actions left; a won level
  brightens every bridge of the shown step and every reached island without moving any position; camera from eye (0, 1.9,
  1.6) to (0, 0, 0.1) fitted to x −1 … 1, z −0.7 … 1.0, y 0 … 0.2 with a 5 % margin for aspect 0.4 … 2.5; `project`;
  fallback coloured parts) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesSceneGeometryTests.swift` (finite and bounded
  for extreme settings — 2 and 8 islands, 1 and 12 strings, every string a bridge, none a bridge, budgets 1 and 60,
  4 steps; every island top, membrane midpoint, gauge bar and pip inside the view with margin at 7 aspects; same
  positions at every tier; marks filled exactly where the kernel's swing reaches the threshold; gauge bars at 0, half and
  the budget; a won level's bridges and reached islands brighter and in place); agent B; `--name host-3`
- [X] T-R02G1203-005 [P] [US2] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesExperienceCore.swift` — Verified 2026-11-23: host-4 exit 0 (HarmonicBridgesExperienceCoreTests 12 and HarmonicBridgesRendererPurityTests 2: conformance, seeds to levels, the candidate table equal to the 100 witnesses' skipped, every control and refusal code incl. not-whole, undo restores the digest, wins and failures, level changes, payload round trip and refusals; 200 seeded snapshots never change digest, state or verdict at any time or tier and their report equals the kernel's exact report); agent C's adapter retested by the lead
  (controls "string.tune [s, p], crossing.test, play.undo, play.redo, level.next"; digest "level number and play
  fingerprint"; schema 1 `{level, records}`; quality profile of three levels (the Core's `qualityTiers` equals the
  presenter's levels); each level certified directly from a table of its witness's `skipped` candidate, the whole
  generator only if that fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesExperienceCoreTests.swift` (conformance; undo
  restores the digest; snapshot round trip and refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesRendererPurityTests.swift` (200 seeded
  snapshots: tier, time and snapshot never change digest or verdict; the drawn wave never changes a bridge or mark);
  agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks pass.

- [ ] T-R02G1203-006 [US3] [US4] Create `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesExperience.swift`,
  `…Presenter.swift`, `…BridgeScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and
  Reduce Flashing; the presenter declares `probes(_:)` — two ground corners, as the round-two X gates require — and its
  quality levels equal the Core's `qualityTiers`), `…Controls.swift` (labelled string − and +, peg − and +, tune, test,
  undo, redo, next level; string 0 chosen at its current peg when a level opens, clamped), and
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G12-QA-001 … 080) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesScenariosTests.swift` and
  `Packages/ExperiencesRound02/HarmonicBridges/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example →
  `r02-g13.acoustic-constellator`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at time 0 at three
  tiers on 5 levels, at points at least 6 px from any other element: island top centre luminance 0.1 from the ground with
  red above blue by 0.05; membrane midpoint 0.08 from the ground with blue above red by 0.05; the gauge's first bar 0.1
  from the ground; ground background within 0.05; tier coordinates; fallback; resize and zero size; memory warning
  releases and the next frame rebuilds; Reduce Motion; a failure outlines the broken step and string; a won level
  brightens its bridges; identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  HarmonicBridgesExperienceTests`; `--name packages -- python3 scripts/check_experience_packages.py`; `--name
  catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1203-007 Docs: `docs/architecture/harmonic-bridges.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1203-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1203-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1203-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1203-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1203-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1203-006)
- [ ] T-R02G1203-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look (feature 403's convergence lesson) is part of T-003 and
T-004 from the start.
