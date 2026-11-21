# Feature Specification: R02-G03-03 — Wave Knot Keeper: procedural materials and hero renderer

**Feature Branch**: `323-wave-knot-keeper-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G03-03 (migration ledger, game feature of experience R02-G03) · ID namespace FR-R02G0303-###,
SC-R02G0303-###, T-R02G0303-###

**Input**: User description: the archived R02-G03-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Wave Knot Keeper, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/323-wave-knot-keeper-procedural-materials-and-hero-renderer`;
  FR-R02G0303-###, SC-R02G0303-###, T-R02G0303-###.
- **Packaging (ADR-0009):** the source's `Apps/WaveKnotKeeper` becomes the experience target
  `WaveKnotKeeperExperience` (with its tests) in `Packages/ExperiencesRound02/WaveKnotKeeper/Experience` beside
  the existing `WaveKnotKeeperCore`; the experience `r02-g03.wave-knot-keeper` (free) is registered in the catalog
  as a candidate (not available) and linked into the one app, as Lissajous Labyrinth was at R02-G02-03; it becomes available only
  at its gate X-R02-G03.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 72" (the 100 certified levels of R02-G03-02
  are the content). **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as `{device}` tasks for
  after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F08 (curve sampling,
  frames and ribbon meshes), R02-F10 (quality tiers) and the shared custom-shader mesh renderer added at R02-G01-03,
  through the existing VisualCore packages; the kernel and certified levels of R02-G03-01 and -02.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only, 2026-11-21): Lissajous Labyrinth's experience (R02-G02-03 … 10) is the pattern in this package — a Core
adapter, an immutable scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
with presenter, scene and controls, a scenario manifest with 80 acceptance scenarios, a registration with content facts,
and the public `ShaderMeshRenderer`; the Wave Knot Keeper kernel provides the level, play, rules, geometry summary and
the certified catalog with its pinned digest (12c8ecb8…933f); the archive holds the rows R2-G03-QA-001 … 080 and the
visual design (glasslike light ropes, parallel-transport tubes with glow shells, palette pearl, sapphire and ember);
`AppModelTests` uses `r02-g03.wave-knot-keeper` as its example of an unregistered candidate.

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the rope's control points (kernel
  units −16 … 16) scaled by 1/8 into world units; the tube follows the control polygon itself, each segment straight and
  each corner rounded by a quadratic arc between the points a quarter of the way along the two adjacent segments, so the
  drawn crossings are the rules' crossings (a spline through the points could cross differently); tube radius 0.1 world
  units with parallel-transport frames, a glass body in pearl and sapphire (fresnel rim) and an additive glow shell. At
  each projected crossing of the summary the over-strand carries an ember caustic pulse (0.5 Hz, presentation time
  only). Handles are small pearl spheres at the control points (ember when selected); gates are translucent sapphire
  cubes with bright edges. The camera is a fixed authored perspective looking down the z axis, tilted 20° about x, fitting
  the figure's bounding sphere (orbit comes in R02-G03-04). Nothing drawn is consulted by the rules. Impact:
  FR-R02G0303-001, 002, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): 16 tube sides, 8 corner samples, 2 glow shells;
  `level-1`: 10 sides, 4 corner samples, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): 6 sides, 2 corner
  samples, no glow. Control points, handles and gates sit at the same coordinates at every tier. Levels are ordered
  richest first; the presenter logs each tier change with its reason. Impact: FR-R02G0303-004; SC-R02G0303-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects the control
  points, the segment midpoints and the gate centres through the same camera and gives the palette. Simulator tests
  render offscreen at 1,152 × 768 (the size Lissajous settled on for thin geometry) and check that each projected control
  point and segment midpoint (not hidden behind a gate) lies within 3 pixels of a pixel brighter than the background by
  at least 0.15 in luminance, that each handle's centre pixel is within 0.15 per channel of pearl (or ember when
  selected) and that the background matches the palette's night within 0.05 away from geometry. Palette: night #05070F,
  pearl #E8E4DA, sapphire #2F6FD8, ember #E0703A. Impact: FR-R02G0303-006; SC-R02G0303-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `WaveKnotKeeperSceneSnapshot` (points, gates, target, summary with each projected crossing's segment pair and over
  strand, stage, selected point, frame time) made from the adapter; it never holds the kernel. If a program fails to
  compile or link, the scene draws the level-2 tube unlit with the shared unlit mesh renderer, keeps `fallbackReason`
  and keeps running; tier changes go to its `tierLog`. Reduce Motion holds the pulses at time 0; Reduce Flashing caps
  the glow gain. Impact: FR-R02G0303-003, 007; SC-R02G0303-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g03.wave-knot-keeper` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette above, the
  scenario manifest, no permissions, a summary of at most 300 characters, content facts: 100 levels and the pinned
  catalog digest); `project.yml` and the app's experience registry link `WaveKnotKeeperExperience` as a candidate
  (`available: false` until X-R02-G03), opening at seed 0 (level 1) like the other round-two puzzles; `AppModelTests`
  switches its unregistered example to the next round-two game (`r02-g04.hue-compass`). The adapter
  (`WaveKnotKeeperExperienceCore`) prepares certified level (seed mod 100) + 1 and accepts `point.move [point 0…15,
  direction 0…5]` (whole numbers; the kernel refuses out-of-range, out-of-bounds, coincident, crossing and tension
  moves), `point.select [point]` (presentation only, no digest change), `play.undo`, `play.redo` and `level.next`; its
  digest is the level number and the play's fingerprint (never the record history, so undo restores the earlier digest);
  snapshot schema 1 `{level, records}`. Impact: FR-R02G0303-005, 008, 009; SC-R02G0303-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the glass rope (Priority: P1) 🎯

A player opens Wave Knot Keeper and sees the level's closed rope drawn as a glasslike light tube braided through space in
pearl, sapphire and ember, with its control handles, the crossing gates of the level and gentle caustic pulses running
along the strands that pass over others.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose rope, handles,
gates and palette are where a CPU reference of the same snapshot says they are.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose rope, handle and
   gate pixels match the CPU reference within stated bounds.
2. **Given** a point move from the rule kernel, **When** the next frame is drawn, **Then** the drawn rope follows the
   moved point, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, time or rendering failure, the drawn image never changes whether a level is won
or failed; the renderer only reads the kernel's immutable snapshot.

**Why this priority**: renderer purity (R2-G03-INV-10) is a certification invariant.

**Independent Test**: changing tier, time and frame count never changes the kernel's digest; a failed shader leaves the
logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer samples and simpler effects but keeps the same objective, coordinates and
indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the same control points, handles and gates at the same places; only tube
sides, corner samples and glow shells change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see it
as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the whole figure (rope, handles and gates) inside the view with a
  margin of at least 5 % on each side.
- **Extreme ropes** (16 points at the bounds −16 … 16, nearly coincident neighbours, the largest tension): geometry and
  uniforms stay finite and bounded.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the caustic pulses stand still (time 0); Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0303-001**: The experience MUST render the rope as a closed tube mesh built from code along the kernel's
  control polygon (parallel-transport frames), its control handles and the crossing gates as generated meshes, entirely
  from generated geometry and shader code, with no image assets.
- **FR-R02G0303-002**: Rope materials MUST show a glasslike tube with a fresnel rim, an emissive glow shell and caustic
  pulses on over-strands at projected crossings; handles MUST show normal and selected states, and gates a translucent
  volume with edges, all in the palette pearl, sapphire and ember, computed in shaders.
- **FR-R02G0303-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict (renderer purity).
- **FR-R02G0303-004**: The experience MUST offer three quality tiers that change only tube sides, corner samples and glow
  shells, never coordinates, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0303-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for point moves, undo, redo and next level, digest, snapshot and restore), opening certified levels of
  R02-G03-02.
- **FR-R02G0303-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be checked
  on the simulator within stated bounds.
- **FR-R02G0303-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as the
  edge cases state.
- **FR-R02G0303-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0303-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the rope's points, the gates, the target, the summary (crossings, writhe, degenerate), the
  projected crossings with their over-strand, stage and the frame time.
- **Rope tube**: the drawn closed tube along the control polygon at a tier's sides and corner samples, with its glow.
- **Quality tier**: 0, 1 or 2, with its tube sides, corner samples and glow shells.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0303-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: rope, handle
  and gate pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0303-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0303-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for every
  extreme setting.
- **SC-R02G0303-004**: The candidate passes the experience package, registry, catalog and content checks and opens in the
  app's unit tests; it is not listed as available.
- **SC-R02G0303-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0303-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Handle dragging, orbit and gestures are R02-G03-04; hints and progression R02-G03-05; accessibility and polish
  R02-G03-06; persistence R02-G03-07. This feature gives the experience a minimal control panel (a point picker, six direction
  buttons, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Aurora Loom, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`, fixtures
  and the 80 acceptance scenarios of the archived matrix (R2-G03-QA-001 … 080), and its registration carries the content
  facts (100 levels and the pinned catalog digest), because the content audit applies to registered candidates.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (parallel-transport tube splines, additive glow shells) | FR-R02G0303-001 |
| Signature shader (glasslike light ropes, caustic pulses, emissive) and palette | FR-R02G0303-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0303-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0303-004 |
| INV-10 renderer purity, INV-08 stability | FR-R02G0303-003; SC-R02G0303-002, 003 |
| Real render captures | FR-R02G0303-006 |
| "Register it in the catalog" (override) | FR-R02G0303-008 |
| No Stage One breakage | FR-R02G0303-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G03.
