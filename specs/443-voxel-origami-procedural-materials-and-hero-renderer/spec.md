# Feature Specification: R02-G15-03 — Voxel Origami: procedural materials and hero renderer

**Feature Branch**: `443-voxel-origami-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G15-03 (migration ledger, game feature of experience R02-G15) · ID namespace FR-R02G1503-###,
SC-R02G1503-###, T-R02G1503-###

**Input**: User description: the archived R02-G15-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Voxel Origami, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/443-voxel-origami-procedural-materials-and-hero-renderer`; FR-R02G1503-###,
  SC-R02G1503-###, T-R02G1503-###.
- **Packaging (ADR-0009):** the source's `Apps/VoxelOrigami` becomes the experience target `VoxelOrigamiExperience`
  (with its tests) in `Packages/ExperiencesRound02/VoxelOrigami/Experience` beside the existing `VoxelOrigamiCore`; the
  experience `r02-g15.voxel-origami` (free) is registered in the catalog as a candidate (not available) and linked into
  the one app, as Moonlit Mechanism was at R02-G14-03; it becomes available only at its gate X-R02-G15.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 88" is a milestone figure — the catalog is
  the 100 certified levels of R02-G15-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G15-01 and -02.
- **Model:** feature 433 (Moonlit Mechanism's hero renderer and experience).

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
433's answers where the games agree. Facts checked in code (read-only, 2026-11-24): Moonlit Mechanism's experience
(R02-G14-03 … 10) is the pattern in this package — a Core adapter with a table of certified candidates, an immutable
scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target (`…Experience.swift`,
presenter, scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with content facts in
`Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Voxel Origami kernel provides the level (4 … 12
cubes with parents, rest directions and start turns; the target; the orientations; the budget), the pose (cells and
orientations), the shape report (occupancy, canonical hash, covered count, match), the covered alignment (rotation and
translation), the play (turn, undo, redo, stages, failures collision, sweep and budget) and the certified catalog of
R02-G15-02 (5 … 10 cubes); `AppModelTests` uses `r02-g15.voxel-origami` as its synthetic unregistered candidate and the
next round-two game is `r02-g16.starlit-cartouche`; the archived matrix has 80 acceptance rows R2-G15-QA-001 … 080; the
catalog's design gives the palette "frosted ivory, laser turquoise and hot pink edge", the hero "chains of luminous cubes
collapsing into radiant sculptural forms" and the geometry "instanced cubes with chamfered normals and hinge transform
tree".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the kernel's cells map to world
  space by w(c) = (c − m) · s, where m is the centre of the bounding box of the occupied cells together with the target
  cells at the best allowed alignment (the covered count's rotation and translation), and s = 1.5 / (e + 1) with e the
  box's largest extent in cells; y is up. Drawn back to front by distance from the eye (depth testing is off, the shared
  mesh renderer's path; the painter's order is the camera-distance order of the elements' centres): the night backdrop
  (a large quad behind everything); the target outline, one wireframe cube of side 0.96 s per target cell at its best
  alignment, edges of the tier's thickness in turquoise; the cubes, each a chamfered cube of side 0.9 s at w(cell),
  turned by its orientation, frosted ivory with faceted shading, an inner glyph on its faces (solid turquoise when the
  cube's cell is a target cell, hollow grey otherwise) and (cube index mod 6) + 1 dots on its +z face; the hinge marks,
  one bar per hinge on the face between its parent and its cube (length 0.6 s along the hinge axis, width 0.12 s), grey,
  the chosen hinge striped hot pink; the gauges in screen-facing world space below the scene: the covered pips, one per
  cube at y = −1.05 from x = −0.8 to 0.8, lit for the covered count; the moves bars, `budget` bars at y = −1.2 from
  x = −0.9 to 0.9 (each 1.8 / budget wide with a gap of a fifth, 0.04 tall), lit for the actions left; the glow is
  additive and drawn last. The chosen hinge is presentation state of the adapter (`hinge.choose [h]`, never in the
  digest), the first hinge that can turn at opening. The camera is a fixed authored perspective (eye (1.4, 1.1, 2.6)
  looking at (0, −0.1, 0)) fitted to the box x −0.95 … 0.95, y −1.25 … 0.95, z −0.95 … 0.95 with a 5 % margin for
  aspect 0.4 … 2.5. Nothing drawn is consulted by the rules; the drawn cubes sit in the kernel's cells. Impact:
  FR-R02G1503-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): a chamfer of 0.12 of the cube's side in 2 bevel
  steps, target edges 0.06 s thick and 2 glow shells around lit cubes and the target outline; `level-1`: 1 bevel step,
  edges 0.05 s, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): plain cubes without a bevel, edges 0.04 s, no
  glow. Cubes, glyphs, dots, hinge marks, the target outline, gauges, colours and positions are the same at every tier.
  Levels are ordered richest first; the presenter logs each tier change with its reason. Impact: FR-R02G1503-004;
  SC-R02G1503-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects through the same
  camera every cube's centre and every hinge mark's centre, the first covered pip and the first moves bar, orders them
  by camera distance as the painter does, and gives the palette. Simulator tests render offscreen at 1,152 × 768 at time
  0 and check, at points at least 6 pixels from every element drawn after them, that a cube's centre is brighter than
  the night backdrop by at least 0.25 in luminance; that the chosen hinge's centre has red above blue by at least 0.08
  (hot pink); that the first moves bar differs from the backdrop by at least 0.1; and that the backdrop matches the night
  colour within 0.05 away from geometry. Palette: night #0B0D16, ivory #EDE8DC, ivory shade #B9B2A3, target turquoise
  #2EE6D6, target glow #8FF5EC, hinge #7F7A70, hinge chosen #FF3C8C, glyph solid #2EE6D6, glyph hollow #4A4E5C, dots
  #3A3D48, covered lit #FF3C8C, covered unlit #2A2D3A, moves lit #2EE6D6, moves unlit #2A2D3A, broken outline #FF6B4A,
  glow #FFF4E0. Impact: FR-R02G1503-006; SC-R02G1503-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `VoxelOrigamiSceneSnapshot` (the cubes' cells and orientations, the parents and rest directions, the hinges' quarter
  turns and which can turn, the chosen hinge, the target cells at the best alignment, the shape report, stage, failure,
  actions left, budget, level number and presentation time) made by the adapter; it never holds the kernel. If a program
  fails to compile or link, the scene draws the level-2 geometry unlit with the shared unlit mesh renderer, keeps
  `fallbackReason` and keeps running; tier changes go to its `tierLog`. Reduce Motion draws the cubes at their cells
  without a turning preview; Reduce Flashing caps the glow gain. A failure outlines the moving cube and the cube in its
  way in the broken colour and marks the cell they meet in, and the failure text names them, as the kernel's reason
  does. Impact: FR-R02G1503-003, 007; SC-R02G1503-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g15.voxel-origami` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the scenario
  manifest `Packages/ExperiencesRound02/VoxelOrigami/scenario-manifest.json`, no permissions, a summary of at most 300
  characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's experience registry
  link `VoxelOrigamiExperience` as a candidate (`available: false` until X-R02-G15), opening at seed 0 (level 1);
  `AppModelTests` switches its synthetic unregistered candidate to the next round-two game
  (`r02-g16.starlit-cartouche`). The adapter (`VoxelOrigamiExperienceCore`) prepares certified level (seed mod 100) + 1
  from its table of certified candidates (the whole generator only if that candidate no longer certifies) and accepts
  `hinge.turn [h, ±1]`, `play.undo`, `play.redo`, `level.next` and `hinge.choose [h]` (whole numbers only); the kernel
  refuses everything out of range or out of stage, and `hinge.choose` refuses a hinge the level does not have; its
  digest is the level number and the play's fingerprint (never the record history or the chosen hinge, so undo restores
  the earlier digest); snapshot schema 1 `{level, records}`. Impact: FR-R02G1503-005, 008, 009; SC-R02G1503-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch a chain of luminous cubes fold toward a radiant target sculpture (Priority: P1) 🎯

A player opens Voxel Origami and sees a chain of frosted-ivory cubes joined by glowing hinges, floating beside the
faint turquoise outline of the target solid. Each cube has chamfered edges and a soft inner light; the hinge that is
chosen shines hot pink along its edge. Turning a hinge swings every cube beyond it; when the chain fills the target,
the cubes flare and the outline locks into a radiant sculpture.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose cubes, hinge
marks, target outline and gauges are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose cube, hinge,
   target and gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the cubes, the chosen hinge and
   the gauges follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn cubes sit in the
kernel's exact cells, never in a separately computed pose.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses no chamfer bevel and no glow but keeps the same objective, cubes, hinges, target,
colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the cubes, hinge marks, target outline and gauges at the same places; only
the bevel, glow and target outline thickness change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits every cube, the target outline and the gauges with a margin of at least
  5 % on each side.
- **Colour-blind players:** each cube carries (index mod 6) + 1 dots on one face, the chosen hinge a striped bar,
  cubes in a target cell a solid inner glyph and cubes outside it a hollow one, the target an outline; moves and the
  covered count are rows of shapes; every cube, hinge and measure can be named in words by the kernel, so no
  information is carried by hue only.
- **A failure (collision, sweep or budget):** the moving cube and the cube in its way are outlined and the cell they
  meet in marked; the gauges show what was reached and the failure shown names it, as the kernel's reason does.
- **A won level:** every cube is lit and the target outline flares; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** cubes are drawn at their cells without a turning preview; Reduce Flashing caps the glow to the
  shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1503-001**: The experience MUST render the cubes as generated chamfered cube meshes placed by the hinge
  transform tree, the hinge marks, the target outline and the moves and covered gauges entirely from generated geometry
  and shader code, with no image assets.
- **FR-R02G1503-002**: Materials MUST show frosted-ivory cubes with faceted procedural shading, laser-turquoise target
  light and hot-pink hinge edges, computed in shaders; every element also has its shape or pattern.
- **FR-R02G1503-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict.
- **FR-R02G1503-004**: The experience MUST offer three quality tiers that change only the chamfer bevel, glow and target
  outline thickness, never cubes, hinges, targets, colours, objective or indicators; the selected tier and the reason
  MUST be logged.
- **FR-R02G1503-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for turning a hinge, undo, redo, next level and choosing the shown hinge, digest, snapshot and restore),
  opening certified levels of R02-G15-02.
- **FR-R02G1503-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1503-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1503-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1503-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the cubes (cells and orientations), the hinges (quarter turns, which can turn), the chosen hinge,
  the target cells at the best alignment, the shape report (covered count, match), stage, failure, actions left, budget,
  level number and presentation time.
- **Voxel geometry**: the cube meshes, the hinge marks, the target outline and the gauges.
- **Quality tier**: 0, 1 or 2, with its bevel, glow and outline thickness.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1503-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: cube, hinge,
  target and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1503-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G1503-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1503-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1503-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1503-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (tap a hinge, drag along its arc to a quarter turn, orbit) are R02-G15-04; hints and progression R02-G15-05;
  accessibility and polish R02-G15-06; persistence R02-G15-07. This feature gives the experience a minimal control panel
  (hinge −/+ to choose, turn −/+, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Instanced cubes
  with chamfered normals and hinge transform tree" are generated meshes placed at the kernel's exact cells; "glowing cube
  nets morph into compact 3D sculptures" is read as the kernel's poses drawn with a glow that grows with the covered
  count, so the shape seen is always the shape judged.
- Like Moonlit Mechanism, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G15-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G15-02).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (instanced cubes with chamfered normals and hinge transform tree) | FR-R02G1503-001 |
| Signature shader (glowing cube nets morph into compact 3D sculptures; procedural faceted materials) and palette (frosted ivory, laser turquoise, hot pink edge) | FR-R02G1503-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1503-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1503-004 |
| Renderer purity, stability | FR-R02G1503-003; SC-R02G1503-002, 003 |
| Real render captures | FR-R02G1503-006 |
| "Register it in the catalog" (override) | FR-R02G1503-008 |
| No Stage One breakage | FR-R02G1503-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G15.
