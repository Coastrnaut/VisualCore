# Feature Specification: R02-G22-03 — Mycelium Architect: procedural materials and hero renderer

**Feature Branch**: `513-mycelium-architect-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G22-03 (migration ledger, game feature of experience R02-G22) · ID namespace FR-R02G2203-###,
SC-R02G2203-###, T-R02G2203-###

**Input**: User description: the archived R02-G22-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Mycelium Architect (code-only
hero: "organic veins pulsing like a starlit subterranean city"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/513-mycelium-architect-procedural-materials-and-hero-renderer`; FR-R02G2203-###,
  SC-R02G2203-###, T-R02G2203-###.
- **Packaging (ADR-0009):** the source's `Apps/MyceliumArchitect` becomes the experience target
  `MyceliumArchitectExperience` (with its tests) in `Packages/ExperiencesRound02/MyceliumArchitect/Experience` beside
  the existing `MyceliumArchitectCore`; the experience `r02-g22.mycelium-architect` (free) is registered in the catalog
  as a candidate (not available) and linked into the one app, as Binary Gardens was at R02-G21-03; it becomes available
  only at its gate X-R02-G22.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 84" is a milestone figure — the catalog is
  the 100 certified levels of R02-G22-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel of R02-G22-01 and the certified levels of R02-G22-02 (this gate starts after R02-G22-02 is
  recorded).
- **Model:** feature 503 (Binary Gardens' hero renderer and experience), itself modelled on feature 493.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
503's answers where the games agree. Facts checked in code (read-only, 2026-11-27): Binary Gardens' experience as
recorded at R02-G21-03 is the pattern in this package — a Core adapter (`…ExperienceCore`) with a table of certified
candidate indices (each witness's `skipped`), an immutable scene snapshot, a CPU projection reference, GLSL sources in
the Core with material codes in the uv stream (the shared `ShaderMeshRenderer` binds only position, normal and uv), an
iOS-only experience target (`…Experience.swift`, presenter, scene, controls), a presenter that declares frame
`probes(_:)` and quality levels equal to the Core's `qualityTiers`, a fallback through the shared unlit mesh renderer
with `fallbackReason` and `tierLog`, a scenario manifest with 80 acceptance scenarios and a registration with content
facts in `Catalog/registrations.json`; the window surface has no depth buffer, so everything is drawn in painter's
order with depth testing off and no face culling. The Mycelium Architect kernel (`Packages/ExperiencesRound02/
MyceliumArchitect/Core`) provides the level (a 4 … 32 board, root, 1 … 6 terminals, rocks, toxins, fixed nutrients,
optional sites, field and penalties, limits, pulses, budget and limit), the arrangement, the exact growth report (the
field, steps, the grown network in growth order with pulses and parent indices, total weight, terminal pulses and path
weights, pulses run, first failure), the play and words for every cell, step, terminal and failure; R02-G22-02 adds the
100-level catalog (boards 8 … 16, every level with sites) with witnesses and the pinned digest
3a2b82b6363ef37ad1678847640b07e33f58e2ac2127ef39e9a34ff32797b040. No `MyceliumArchitectExperience` exists yet.
`AppModelTests` uses `r02-g22.mycelium-architect` as its synthetic unregistered candidate; the next round-two game is
`r02-g23.erosion-painter`; the archived matrix has 80 acceptance rows R2-G22-QA-001 … 080; the catalog's design gives the
palette "emerald, copper and violet roots", the hero "organic veins pulsing like a starlit subterranean city", the
geometry "instanced tapered cylinder branch segments and procedural cap mushrooms" and the signature shader "recursive
hyphae bloom under translucent luminous caps".

- Q: What exactly does the scene show, and how does it map the board to space? → A: the board lies in the plane z = 0
  (x right, y up the board, z up out of it). One fit rule per level: with s = 1.9 / max(W, H), cell (c, r) has its
  centre at ((c + 0.5 − W/2)·s, 0.05 + (H/2 − r − 0.5)·s, 0), so every board fills the same square of side 1.9 centred
  at (0, 0.05) and nothing a player does changes the scale. Drawn in painter's order with depth testing off and no face
  culling: the backdrop (a still vertical gradient from cave #06070A at the bottom to cave top #12161C at the top with
  hashed spore points, spore #9FE8C8, covering at most 2 % of its area — the "starlit" city seen from below — the same
  at every tier); the floor plate under the board (floor #14171C) with grid lines (grid #1E232B); site marks (a dashed
  square inset by 0.1·s, site #4A5568); toxins (a pool of radius 0.42·s with concentric ripples, toxin #7B3FB8); rocks
  (a raised rounded block of 0.9·s with copper veins drawn in the shader, rock #3B2F2A, vein copper #C8743A); blockers
  (a stone disc of radius 0.38·s with a ring, blocker #2A2D33, ring #8A8F98); nutrients (an orb of radius 0.3·s, fixed
  and placed both nutrient #E08A3C, a placed one with an outer ring; consumed nutrients drop to a dim ring); the veins
  (one tapered tube per grown segment up to the shown pulse, from the parent cell's centre to the child's, radius from
  0.16·s at the root end down to 0.06·s by the child's path weight over the network's largest path weight, emerald
  #2FE08A, whose brightness pulses outward along the path weight with presentation time; a small bloom at every cell
  where a nutrient was consumed); seeds (a short sprout from the root in each seeded direction, sprout #5BE38F); the
  root cap (radius 0.36·s, cap #9FF2D0); the terminal caps (radius 0.42·s; closed and hollow when not reached by the
  shown pulse, cap closed #4B6B60, open and lit when reached, cap open #C9FFE9, with a ring of terminal + 1 pips); the
  gauges below the board: a weight bar plate from x = −0.95 to 0.95 at y = −1.12 (gauge plate #1A2347) whose fill
  (weight #2FE08A) maps 0 … the nutrient budget, with a tick at the limit (limit #E0E6EE) and the bar's end at the
  budget; a row of terminal pips at y = −1.24 (filled when reached, hollow otherwise); the actions bars at y = −1.34
  (each 1.9 / budget wide with a gap of a fifth, 0.035 tall), lit for the actions left (actions lit #E08A3C, actions
  unlit #1E2648). The glow is additive and drawn last. The network shown is the report of the current arrangement; the
  shown pulse is presentation state of the adapter (`growth.show [pulse]`, 0 … pulses run, never in the digest), equal
  to the pulses run at opening and after every action, undo, redo, `level.next`, reset and restore, and never advanced
  by time. The camera is a fixed authored perspective (eye (0, −1.9, 2.8) looking at (0, −0.3, 0)) fitted to the box
  x −1.05 … 1.05, y −1.45 … 1.05, z 0 … 0.25 with a 5 % margin for aspect 0.4 … 2.5. Nothing drawn is consulted by the
  rules. Impact: FR-R02G2203-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): vein tubes of 8 sides, caps of 16 segments,
  hyphae fuzz of 6 strands at every branch point and under every open cap, 24 drifting spores and 2 glow shells around
  the root, the open caps and the blooms; `level-1`: 6 sides, 12 segments, 3 strands, 12 spores, 1 glow shell; `level-2`
  (the design's "Tier 0, D3-safe"): 4 sides (still tapered), 8 segments, no fuzz, no spores, no glow. The backdrop, the
  floor and grid, the cells, the network's segments and radii, the caps' positions and sizes, the pips, gauges, actions
  bars and colours are the same at every tier. Levels are ordered richest first; the Core's `qualityTiers` equals the
  presenter's levels; the presenter logs each tier change with its reason. Impact: FR-R02G2203-004; SC-R02G2203-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects through the same
  camera the board centre, the root's centre, every terminal's centre, the weight plate's left margin (x = −0.925) and
  the first actions bar, and gives the palette. Simulator tests render offscreen at 1,152 × 768 at the full shown pulse
  and check, at points at least 6 pixels from every element drawn after them, that the root cap's centre is brighter
  than the backdrop at that point by at least 0.15 in luminance; that every reached terminal's centre is brighter by at
  least 0.3 and every unreached one differs by at least 0.05 (in the unlit fallback: the flat colour within 0.1); that
  the first actions bar (lit) has red above blue by at least 0.08 (copper); that the weight plate's left margin differs
  from the backdrop by at least 0.05; and that the median of a 9 × 9 pixel backdrop patch in a lower corner matches the
  gradient colour at its height within 0.06. Palette: cave #06070A, cave top #12161C, spore #9FE8C8, floor #14171C,
  grid #1E232B, site #4A5568, toxin #7B3FB8, rock #3B2F2A, vein copper #C8743A, blocker #2A2D33, ring #8A8F98, nutrient
  #E08A3C, emerald #2FE08A, sprout #5BE38F, cap #9FF2D0, cap closed #4B6B60, cap open #C9FFE9, gauge plate #1A2347,
  weight #2FE08A, limit #E0E6EE, actions lit #E08A3C, actions unlit #1E2648, broken #FF6B5E, glow #F2FFF8. Impact:
  FR-R02G2203-006; SC-R02G2203-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `MyceliumArchitectSceneSnapshot` (the level's board, root, terminals, rocks, toxins, fixed nutrients and sites; the
  arrangement; from the kernel's report the grown cells in growth order with their pulses and parent indices, each
  cell's path weight, the consumed nutrients, the total weight, the terminal pulses, the pulses run; the shown pulse,
  the fit scale s, stage, failure, actions left, budget, nutrient budget, weight limit, level number and presentation
  time) made by the adapter; it never holds the kernel. If a program fails to compile or link, the scene draws the
  level-2 geometry unlit with the shared unlit mesh renderer, keeps `fallbackReason` and keeps running; tier changes go
  to its `tierLog`. Reduce Motion stops the vein pulses, ripples and spores; Reduce Flashing caps the glow gain. A
  failure marks the failing element in the broken colour (toxic: a broken ring on the entered toxin cell; starved: a
  dashed broken outline on the cell the step could not grow into and the weight bar's end; unreached: a broken ring on
  the named terminal; overweight: the weight fill past the limit tick), and the failure text names it, as the kernel's
  `failureDescription` does. Impact: FR-R02G2203-003, 007; SC-R02G2203-002.
- Q: How is the experience registered, what does the adapter accept and how do the streams carry materials? → A:
  `Catalog/registrations.json` gains `r02-g22.mycelium-architect` (capabilities of at most 40 characters, tiers
  `level-0` … `level-2`, the palette #06070A, #2FE08A, #E08A3C, #7B3FB8, #12161C, the scenario manifest
  `Packages/ExperiencesRound02/MyceliumArchitect/scenario-manifest.json`, no permissions, a summary of at most 300
  characters, content facts: 100 levels and the pinned catalog digest of R02-G22-02); `project.yml` and the app's
  experience registry link `MyceliumArchitectExperience` as a candidate (`available: false` until X-R02-G22), opening
  at seed 0 (level 1); `AppModelTests` switches its synthetic unregistered candidate to `r02-g23.erosion-painter`. The
  adapter (`MyceliumArchitectExperienceCore`) prepares certified level (seed mod 100) + 1 from its table of certified
  candidate indices and accepts `cell.nutrient [column, row]`, `cell.blocker [column, row]`, `cell.clear [column, row]`,
  `root.seed [direction]`, `root.unseed [direction]`, `growth.run`, `play.undo`, `play.redo`, `level.next` and
  `growth.show [pulse]` (whole numbers only); the kernel refuses everything off the board, not empty, not a site, over a
  limit, locked or out of stage with its own codes; the declared ranges are column and row 0 … 31, direction 0 … 7 and
  pulse 0 … 128, so the engine refuses only values outside them, and `growth.show` refuses a pulse above the pulses run
  with `r02-g22.pulse` without touching the kernel; its digest (domain `r02-g22.mycelium-architect.v1`) is the level
  number and the play's fingerprint (never the record history or the shown pulse); snapshot schema 1 `{level,
  records}`. Vertex streams as feature 503: `a_uv.x` = material code + value scale · value (a fraction 0 … 1, for
  valued materials only: a vein's path weight over the largest, a bar's fill) + a broken offset when a failure names
  the element; the flats are cut out by signed distance in the fragment shader; a tube vertex carries its ring normal
  in `a_normal`. Programs are GLSL ES 3.00 with at most 16 vec4 uniforms, no texture samplers and only bounded loops; the
  palette constants in the sources equal the CPU's; spores, veins and fuzz come from a fixed hash, never a random
  source. Impact: FR-R02G2203-001, 002, 003, 005, 008, 009; SC-R02G2203-003, 004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch luminous veins grow through a dark cave toward glowing terminals (Priority: P1) 🎯

A player opens Mycelium Architect and sees a dark cave floor from above at a slight angle: copper-veined rocks, violet
toxin pools, the root as a small luminous cap, and the terminals as larger translucent mushroom caps waiting to be
joined. Placed nutrients glow copper and pulse; blockers stand as dark stones with a ring; seeded directions show as
short sprouts from the root. When the growth runs, emerald veins grow segment by segment along the kernel's network,
tapering from the root outward, pulsing with light like a starlit city seen from far below; where a tip feeds on a
nutrient, a branch splits off with a small bloom. Beside the board, gauges show the branch weight against the limit and
the budget, the terminals reached and the actions left.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose cells, veins,
caps, gauges and actions bars are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose rock, toxin,
   terminal, vein, gauge and actions-bar pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the placements, seeds, the
   predicted network and the gauges show the new report, and the win or failure shown matches the kernel exactly.
3. **Given** a shown pulse, **When** it changes, **Then** exactly the segments grown up to that pulse are drawn, while
   the digest is unchanged.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time, shown pulse or rendering failure, the drawn image never
changes the kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn cells,
segments, weights and terminals are the kernel's exact integers.

**Why this priority**: the rules are exact integers; a picture that decided anything would break them.

**Independent Test**: changing tier, presentation time, shown pulse and frame count never changes the kernel's digest;
a failed shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses coarser branch tubes and caps, no hyphae fuzz, spores or glow but keeps the same
objective, cells, network, colours and indicators; the selected tier and its reason are logged.

**Why this priority**: the app runs on three device classes.

**Independent Test**: tiers 0, 1 and 2 draw the cells, veins, caps, gauges and actions bars at the same places; only the
tessellation, hyphae fuzz, spores and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Why this priority**: later features build on the candidate; players must not see it before X-R02-G22.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the board, the gauges and the actions bars with a margin of at least 5 %
  on each side.
- **Extreme levels:** boards of 4 × 4 and 32 × 32, networks of 1 and 2 048 nodes, 1 and 6 terminals, 0 and 12 sites,
  weights 0 and 4 094, budgets 1 and 24: every vertex and uniform stays finite and inside the fitted box.
- **Colour-blind players:** rocks, toxins, nutrients, blockers, sites and terminals differ by shape (rough block, rippled
  pool, pulsing orb, ringed stone, dashed square, cap) as well as colour; a reached terminal is a lit, opened cap and an
  unreached one closed and hollow; gauges carry the weight by length and tick marks for the limit and the budget,
  terminals by filled or hollow pips; actions by a row of bars; every cell, tip, terminal and failure can be named in
  words by the kernel, so no information is carried by hue only.
- **A failure (toxic, starved, unreached, overweight):** the failing element is marked in the broken colour (the toxin
  cell entered, the step that ran out of nutrient, the unreached terminal, the weight gauge past its limit); the failure
  shown names it, as the kernel's reason does.
- **A won level:** every terminal opens and, at the richer tiers, blooms; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** nothing moves by itself (the shown pulse never advances by time; vein pulses and spores are still);
  Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2203-001**: The experience MUST render the cave floor and its cells, rocks, toxin pools, nutrients,
  blockers, sites, the root, the terminal caps, the branch network (instanced tapered tube segments), the gauges and the
  actions bars entirely from generated geometry and shader code, with no image assets.
- **FR-R02G2203-002**: Materials MUST show emerald veins pulsing with light, copper nutrients and rock veins, violet
  toxin, translucent luminous caps and a hyphae bloom where a branch feeds, computed in shaders; every element also has
  its shape or pattern.
- **FR-R02G2203-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time, shown pulse or failure may change the kernel's state, digest or verdict; drawn cells, segments, weights and
  terminal states MUST be the kernel's values up to the shown pulse.
- **FR-R02G2203-004**: The experience MUST offer three quality tiers that change only tessellation, hyphae fuzz, spores
  and glow, never the cells, network, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G2203-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for nutrients, blockers, clears, seeds and unseeds, running the growth, undo, redo, next level and the shown
  pulse, digest, snapshot and restore), opening certified levels of R02-G22-02.
- **FR-R02G2203-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G2203-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G2203-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G2203-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate or
  lists the registered entries, and the kernel's source scans (feature 511's invariant tests read the files directly in `Core/`, feature
  512's generator test the files in `Core/Content/`) stay unchanged because the presentation sources live in a separate
  `Core/Presentation/` folder outside both; every new public name is documented; the reference regression passes;
  the Cores keep running on the host.
- **FR-R02G2203-010**: No information MUST be carried by hue alone (the non-colour twins of the edge cases), and the
  presenter MUST expose its tier log, fallback reason and frame probes for diagnostics, with no telemetry leaving the
  device.

### Key Entities

- **Scene snapshot**: the level's board, root, terminals, rocks, toxins, fixed nutrients and sites; the arrangement; the
  report's network with pulses and parents, weights and terminal states; the shown pulse, fit scale, stage, failure,
  actions left, budget, level number and presentation time.
- **Board geometry**: the cave floor and cells, rock blocks, toxin pools, nutrient orbs, blockers, site marks, the root
  and terminal caps, the tapered vein tubes, the gauges and the actions bars.
- **Quality tier**: 0, 1 or 2, with its tessellation, hyphae fuzz, spores and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2203-001**: On the simulator, frames of 5 certified levels (1, 21, 41, 61, 81) at each tier match the CPU
  reference: cell, vein, cap, gauge and actions-bar positions within the stated tolerance and palette colours within the
  stated distance.
- **SC-R02G2203-002**: Across 200 seeded snapshots, tier changes, time steps, shown-pulse changes and forced shader
  failures never change the kernel digest or verdict.
- **SC-R02G2203-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G2203-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G2203-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G2203-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (place nutrients and blockers by touch, advance growth pulses, undo edits) are R02-G22-04; hints and
  progression R02-G22-05; accessibility and polish R02-G22-06; persistence R02-G22-07. This feature gives the experience
  a minimal control panel (a cell cursor with column and row −/+, nutrient, blocker, clear, seed and unseed by direction,
  pulse −/+, run, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Organic veins
  pulsing like a starlit subterranean city" is read as emerald vein tubes whose brightness travels outward from the root
  in pulses, seen from above against a dark floor; "instanced tapered cylinder branch segments and procedural cap
  mushrooms" as the vein tubes (thicker near the root by path weight) and the root and terminal caps; "recursive hyphae
  bloom under translucent luminous caps" as fine fuzz and glow at branch points and under the caps at the richer tiers;
  "recursive L-systems, instanced leaves, flow network evolution" as the growth drawn pulse by pulse from the kernel's
  network (the judged growth stays the kernel's lattice rules). No physical accuracy is claimed; the shading is a mobile
  approximation.
- Like Binary Gardens, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G22-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G22-02).
- `AppModelTests`' synthetic unregistered candidate moves to the next round-two game, `r02-g23.erosion-painter`.
- New type names avoid the dependency audit's denylist (no ProjectM, MilkDrop or preset-library names).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (instanced tapered cylinder branch segments and procedural cap mushrooms) | FR-R02G2203-001, 002 |
| Signature shader (recursive hyphae bloom under translucent luminous caps; flow network evolution, bioluminescent materials) and palette (emerald, copper and violet roots) | FR-R02G2203-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G2203-003, 005 |
| Quality tiers 0/1/2, tier log | FR-R02G2203-004, 010 |
| Renderer purity, stability (INV-08, INV-10) | FR-R02G2203-003; SC-R02G2203-002, 003 |
| Real render captures | FR-R02G2203-006 |
| Accessibility (non-colour clues, Reduce Motion, Reduce Flashing), observability | FR-R02G2203-007, 010 |
| "Register it in the catalog" (override) | FR-R02G2203-008 |
| No Stage One breakage | FR-R02G2203-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no telemetry, no store listing, no advertising, no gestures beyond
  the minimal control panel, no device run before ImplementationLock-100, no availability before X-R02-G22.
