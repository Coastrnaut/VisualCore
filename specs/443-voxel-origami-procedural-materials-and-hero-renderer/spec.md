# Feature Specification: R02-G15-03 — Voxel Origami: procedural materials and hero renderer

**Feature Branch**: `443-voxel-origami-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Draft

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
- **Colour-blind players:** each cube carries its number pattern of dots on its faces, the chosen hinge a striped bar,
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
