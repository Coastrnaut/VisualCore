# Feature Specification: R02-G02-03 — Lissajous Labyrinth: procedural materials and hero renderer

**Feature Branch**: `313-lissajous-labyrinth-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G02-03 (migration ledger, game feature of experience R02-G02) · ID namespace FR-R02G0203-###,
SC-R02G0203-###, T-R02G0203-###

**Input**: User description: the archived R02-G02-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Lissajous Labyrinth, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/313-lissajous-labyrinth-procedural-materials-and-hero-renderer`;
  FR-R02G0203-###, SC-R02G0203-###, T-R02G0203-###.
- **Packaging (ADR-0009):** the source's `Apps/LissajousLabyrinth` becomes the experience target
  `LissajousLabyrinthExperience` (with its tests) in `Packages/ExperiencesRound02/LissajousLabyrinth/Experience` beside
  the existing `LissajousLabyrinthCore`; the experience `r02-g02.lissajous-labyrinth` (free) is registered in the catalog
  as a candidate (not available) and linked into the one app, as Aurora Loom was at R02-G01-03; it becomes available only
  at its gate X-R02-G02.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 90" (the 100 certified levels of R02-G02-02
  are the content). **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as `{device}` tasks for
  after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F08 (curve sampling,
  frames and ribbon meshes), R02-F10 (quality tiers) and the shared custom-shader mesh renderer added at R02-G01-03,
  through the existing VisualCore packages; the kernel and certified levels of R02-G02-01 and -02.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): Aurora Loom's experience (R02-G01-03 … 06) is the pattern in this package — a Core
adapter (`AuroraLoomExperienceCore`), an immutable scene snapshot, a CPU projection reference, GLSL sources in the Core,
an iOS-only experience target with presenter, scene and controls, a scenario manifest with 80 acceptance scenarios, a
registration with content facts, and the public `ShaderMeshRenderer`; the Lissajous kernel provides
`LissajousLabyrinthLap.samples/verdict`, the Play, the Rules and the certified catalog with its pinned digest
(9c1d5652…e96e); `AppModelTests` uses `r02-g02.lissajous-labyrinth` as its example of an unregistered candidate.

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the lap's 4,096 samples (kernel
  units, ±4,096) scaled by 1/1,024 into world units give the closed path; it is drawn as a camera-facing thread of
  constant width (tangent-space width: each sample offset along the cross product of the tangent and the view direction),
  coloured from cobalt to violet along the lap and fading with depth. The tracer head is a bright copper point at the
  sample of the current tick, advancing slowly: 60 ticks per second of presentation time (a lap in about 68 s), with a
  trail of the last N ticks brighter. Checkpoints are copper rings (dim when not visited in order by the lap, bright when
  visited; the first not visited is outlined); obstacles are violet translucent spheres (generated icospheres) with a
  brighter rim, red-copper where the lap touches them (the verdict's contact). The camera is a fixed authored perspective
  fitting the figure's bounding sphere (orbit comes in R02-G02-04). Nothing drawn is consulted by the rules. Impact:
  FR-R02G0203-001, 002, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): every one of the 4,096 samples, 2 glow passes,
  trail 512 ticks; `level-1`: every 2nd sample, 1 glow pass, trail 256; `level-2` (the design's "Tier 0, D3-safe"):
  every 4th sample, no glow, trail 128. Drawn samples are exact kernel samples at every tier; checkpoints, obstacles and
  the head sit at the same coordinates. Levels are ordered richest first, as the shared quality contract requires. The
  presenter logs each tier change with its reason. Impact: FR-R02G0203-004; SC-R02G0203-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects the drawn path
  samples, checkpoint centres and obstacle centres through the same camera and gives the palette. Simulator tests render
  offscreen at 768 × 512 (aspect 1.5; at 96 × 64 the thin thread and ring bands cover less than a pixel and cannot be
  sampled, measured 2026-11-20) and check that each projected path sample (at the tier's stride, those not hidden behind an
  obstacle) lies within 2 pixels of a pixel brighter than the background by at least 0.15 in luminance, that each
  checkpoint centre's pixel is within 0.12 per channel of its expected colour, and that the background matches the
  palette's night within 0.05 away from geometry. Palette: night #070B1E, cobalt #2F5BD8, violet #8A4FE0, copper
  #D9824A. Impact: FR-R02G0203-006; SC-R02G0203-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `LissajousLabyrinthSceneSnapshot` (dials, level geometry, stage, verdict, visit ticks, frame time) made from the
  adapter; it never holds the kernel. If a program fails to compile or link, the scene draws the level-2 thread unlit with
  the shared unlit mesh renderer, keeps `fallbackReason` and keeps running; tier changes go to its `tierLog`. Reduce
  Motion holds the head at tick 0 and stops the shimmer; Reduce Flashing caps the glow gain. Impact: FR-R02G0203-003, 007;
  SC-R02G0203-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g02.lissajous-labyrinth` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette above, the
  scenario manifest, no permissions, a summary of at most 300 characters, content facts: 100 levels and the pinned
  catalog digest); `project.yml` and the app's experience registry link `LissajousLabyrinthExperience` as a candidate
  (`available: false` until X-R02-G02); `AppModelTests` switches its unregistered example to the next round-two game
  (`r02-g03.wave-knot-keeper`). The adapter (`LissajousLabyrinthExperienceCore`) prepares certified level (seed mod 100) +
  1 and accepts `dial.set [dial 0…3, value]` (whole numbers; the kernel refuses out-of-range, unchanged and non-coprime
  values), `play.undo`, `play.redo` and `level.next`; its digest is the level number and the play's fingerprint (never
  the record history, so undo restores the earlier digest); snapshot schema 1 `{level, records}`. Impact:
  FR-R02G0203-005, 008, 009; SC-R02G0203-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the luminous flower (Priority: P1) 🎯

A player opens Lissajous Labyrinth and sees the tracer's closed path drawn as a luminous ink thread in three dimensions —
a slowly blooming mathematical flower in cobalt, violet and copper — with the checkpoints and obstacles of the level in
the same scene and a bright tracer head moving slowly along the path.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose thread,
checkpoints, obstacles and palette are where a CPU reference of the same snapshot says they are.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose path, checkpoint and
   obstacle pixels match the CPU reference within stated bounds.
2. **Given** a dial change from the rule kernel, **When** the next frame is drawn, **Then** the drawn path follows the
   new dials, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, time or rendering failure, the drawn image never changes whether a level is won
or failed; the renderer only reads the kernel's immutable snapshot.

**Why this priority**: renderer purity (R2-G02-INV-10) is a certification invariant.

**Independent Test**: changing tier, time and frame count never changes the kernel's digest; a failed shader leaves the
logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer samples and simpler effects but keeps the same objective, coordinates and
indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the same path points, checkpoints and obstacles at the same places; only
sample density, thread width detail, trail length and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see it
as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the whole figure (path, checkpoints and obstacles) inside the view with a
  margin of at least 5 % on each side.
- **Extreme dials** (every legal setting, the largest amplitudes, frequency c = 9): geometry and uniforms stay finite
  and bounded.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the tracer head and shimmer stand still (tick 0); Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0203-001**: The experience MUST render the lap's closed path as a thread mesh built from code (the kernel's
  samples with tangent-space width), the checkpoints and the obstacles as generated meshes, and the tracer head, entirely
  from generated geometry and shader code, with no image assets.
- **FR-R02G0203-002**: Thread materials MUST show luminous ink with depth fading, an emissive glow and interference
  shimmer, checkpoints MUST show unvisited, visited-in-order and next states, and obstacles a translucent volume with a
  rim, all in the palette cobalt, violet and copper, computed in shaders.
- **FR-R02G0203-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict (renderer purity).
- **FR-R02G0203-004**: The experience MUST offer three quality tiers that change only sample density, thread detail,
  trail length and glow, never coordinates, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0203-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for dial changes, undo, redo and next level, digest, snapshot and restore), opening certified levels of
  R02-G02-02.
- **FR-R02G0203-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be checked
  on the simulator within stated bounds.
- **FR-R02G0203-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as the
  edge cases state.
- **FR-R02G0203-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0203-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the dials, level geometry (amplitudes, frequency c, checkpoints, obstacles), stage, verdict, visit
  ticks and the frame time.
- **Thread**: the drawn path of one lap at a tier's sample density, with its width and glow.
- **Quality tier**: 0, 1 or 2, with its sample stride, thread detail, trail length and glow passes.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0203-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: path,
  checkpoint and obstacle pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0203-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0203-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for every
  extreme setting.
- **SC-R02G0203-004**: The candidate passes the experience package, registry, catalog and content checks and opens in the
  app's unit tests; it is not listed as available.
- **SC-R02G0203-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0203-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Dials, gestures and the trace scrubber are R02-G02-04; hints and progression R02-G02-05; accessibility and polish
  R02-G02-06; persistence R02-G02-07. This feature gives the experience a minimal control panel (steppers for the four
  dials, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Aurora Loom, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`, fixtures
  and the 80 acceptance scenarios of the archived matrix (R2-G02-QA-001 … 080), and its registration carries the content
  facts (100 levels and the pinned catalog digest), because the content audit applies to registered candidates.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (adaptive curve tessellation with tangent-space width) | FR-R02G0203-001 |
| Signature shader (luminous harmonic curves, interference, emissive) and palette | FR-R02G0203-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0203-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0203-004 |
| INV-10 renderer purity, INV-08 stability | FR-R02G0203-003; SC-R02G0203-002, 003 |
| Real render captures | FR-R02G0203-006 |
| "Register it in the catalog" (override) | FR-R02G0203-008 |
| No Stage One breakage | FR-R02G0203-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G02.
