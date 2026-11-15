# Feature Specification: Tiny Worlds — Phase 02 Camera and scene renderer

**Feature Branch**: `090-tw-p02-camera` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A12-P02 (legacy ledger) · ID namespace FR-A12-2##, SC-A12-2##, T-A12-2##

**Input**: User description: archived manual `apps/12-tiny-worlds.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — an orbit camera with constrained zoom and comfortable control;
  regression fixture — all level-of-detail indices remain in bounds; graphics context ownership stays solely in the
  VisualCore host.
- **Gaps built here** (contract `docs/apps/tiny-worlds/visualcore-contract.json`): G-MATERIALS (a generic optional
  per-vertex colour stream for the mesh renderer and the depth pass), G-PICKING (generic ray intersection against
  boxes, spheres and triangles) and G-CAMERA (the world's camera policy: per-world limits, the eye kept above the
  world's own terrain, direct moves under Reduce Motion, gestures with control alternatives). Props, light
  adjustment and saved worlds stay for A12-P03 (G-PROPS, G-LIGHT, G-WORLDDOC); the full detail-tier policy under
  memory and heat stays for A12-P05 (G-DETAIL) — this phase adds the three terrain detail levels it will choose from.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; the reference
  regression for the VisualCore change runs at X-A12 (owner ruling 2026-11-14); every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`MeshRenderer` (VisualCoreRendering) compiles one program with attributes position (location 0) and normal (location
1), a uniform premultiplied colour, one light direction, an ambient fraction and optional linear fog, uploads an
interleaved position-normal buffer and rebuilds after a context recreation; `DepthMeshPass` draws `Item`s that each
hold a renderer, a model matrix and a colour; `MeshRendererTests` and `DepthMeshPassTests` pin today's pixels;
`Vec4` and `Vec3` exist in `VisualCoreMath`, `OrbitCamera.ray(ndc:aspect:)` gives an origin and direction, and no ray
intersection exists; `GestureAlternatives.missing(gesture:native:)` (VisualCoreExperience) lists gesture actions
without a control; `HeightField.height(atX:z:)` samples the terrain (A12-P01).

- Q: How does a mesh get per-vertex colours without changing existing output? → A: `MeshRenderer` gains an initializer
  with an optional colour stream (one `Vec4` RGBA 0…1 per vertex, straight alpha), uploaded as attribute location 2;
  without a stream the attribute is disabled and its constant value is (1, 1, 1, 1), so the lit colour is multiplied
  by exactly 1 and existing pixels do not change. The stream multiplies the draw colour before lighting. A stream
  whose count differs from the vertex count, or with a non-finite value or one outside 0…1, is refused with
  `MeshError.invalidInput`; the stream is rebuilt with the buffers after a context recreation. `DepthMeshPass` draws
  coloured renderers unchanged (the colour lives with the renderer).
- Q: What exactly does ray intersection return? → A: In `VisualCoreMath`: `Ray3` (origin, unit direction; `init?`
  refuses non-finite values and a zero direction and normalises), `RayHit3` (distance ≥ 0, point, unit normal facing
  against the ray), and `intersect` against an axis-aligned box (min, max), a sphere (centre, radius > 0) and a
  triangle (two-sided, Möller–Trumbore); the nearest hit at distance ≥ 0 wins; a start inside a box or sphere hits at
  distance 0 with the normal −direction; a tangent ray hits once; a ray parallel to a triangle's plane, a degenerate
  triangle or invalid shapes give nil; tolerance 1e-12. A helper picks the nearest of several hits. The ground hit
  over a height field stays app-local: march from the world box entry in steps of half a cell until the ray is below
  the terrain, then bisect 40 times (tolerance under 1e-6 m).
- Q: Which camera policy does each world use? → A: Every world: pitch 10°…75°, distance 10…30 m, target (0, 0.3, 0),
  clearance 0.5 m: the eye's height must exceed the highest terrain sample within 1 m of the point below the eye (9
  samples on a 0.5 m grid) by 0.5 m, else the pitch is raised in 1° steps up to 75°. Drag orbits (0.3° of yaw and of
  pitch per point), pinch zooms (the distance divided by the gesture's scale, each step's factor clamped to
  0.5…2), both sent as the existing `view.orbit` and `view.zoom` actions, so every gesture has its button. Easing
  is the presenter's alone: 0.35 s smoothstep from the drawn view to the state's view; Reduce Motion (or a change of
  it mid-ease) draws the state's view directly. The canvas label is always current; the spoken announcement of a view
  change is posted at most once per second.
- Q: How is a world coloured by height? → A: Per terrain vertex: below sea level 0 (island, city) the low-land
  colour darkened by 25 %; from 0.1 m to 1.2 m a linear blend from low land to high land (clamped outside); the
  asteroid garden's falling edge below −0.5 m blends to the void colour. Colours are a pure function of the height
  and the palette, tested apart from the geometry; the terrain digest (geometry only) and its nine fixtures do not
  change. The renderer's draw colour is white; the sea plane keeps one colour.
- Q: What are the detail levels and how are they chosen? → A: Level 0 is the recipe's resolution, level 1 half and
  level 2 a quarter (island and asteroid garden 64, 32, 16 cells; city 48, 24, 12), over the same 12 m from the same
  height function. The experience declares three quality levels (`level-0`…`level-2`, registration updated) mapped to
  them; the host chooses the level and it is not saved; the state digest and the terrain fixtures stay at level 0. The
  fixture validates all 27 meshes (3 presets × seeds 1–3 × 3 levels) with `validate()` and every index below the
  vertex count. Snapshot schema stays 1.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Look around a tiny world comfortably (Priority: P1) 🎯

A person drags to orbit the world and pinches to zoom, and the view moves smoothly within comfortable limits: never
under the ground, never inside a hill, never too close or too far; the same moves exist as buttons.

**Why this priority**: the manual's Phase 02 MVP and its second journey ("orbit and zoom camera to explore").

**Independent Test**: drive the camera with gestures and controls across a sweep of angles; read the eye position
against the terrain and the limits.

**Acceptance Scenarios**:

1. **Given** any world, **When** the view is dragged or pinched to any extreme, **Then** the camera saturates at its
   limits and the eye stays at least the stated clearance above the terrain beneath and around it.
2. **Given** Reduce Motion on, **When** the view changes, **Then** it moves directly without easing; with Reduce
   Motion off it eases over a short, bounded time.
3. **Given** VoiceOver, **When** a person uses the view, **Then** every gesture has a control alternative and the
   spoken view description updates without flooding (at most once per second).

---

### User Story 2 - A world painted by height in one draw (Priority: P1)

A person sees each world coloured by height — sea or void, low land and high land blended — instead of one flat
colour, while worlds without colours still draw exactly as before.

**Independent Test**: draw each preset; sample pixels of low and high regions; compare a mesh without colours with
its previous output.

**Acceptance Scenarios**:

1. **Given** a coloured terrain, **When** drawn under the same light, **Then** low and high regions show their colours
   within a pixel tolerance.
2. **Given** a mesh drawn without colours, **When** drawn, **Then** its output is unchanged from before this phase.
3. **Given** a colour stream whose length differs from the vertex count, **When** used, **Then** it is refused.

---

### User Story 3 - Point at the ground (Priority: P2)

A person taps the world and hears where the tap met the ground (or that it missed), so the world can later be edited
by pointing (A12-P03).

**Independent Test**: cast rays through screen points; compare the hits with the terrain height there.

**Acceptance Scenarios**:

1. **Given** a tap on the terrain, **When** resolved, **Then** the reported point lies on the terrain within 1 mm
   (vertical distance to the sampled height) and the spoken text names it.
2. **Given** a tap on the sky or void, **When** resolved, **Then** a miss is reported and nothing changes.

---

### User Story 4 - Three detail levels, always in bounds (Priority: P2)

The engineer can trust that each terrain exists at three detail levels whose meshes are valid — every index refers to
an existing vertex — and that the experience can switch between them without changing the world.

**Independent Test**: build every preset at every level for fixed seeds; validate indices; compare digests.

**Acceptance Scenarios**:

1. **Given** each preset, seed and level, **When** generated, **Then** every index is below the vertex count and the
   mesh validates.
2. **Given** a level change, **When** applied, **Then** the world (preset, seed) and its full-detail digest are
   unchanged and the drawing still shows the same terrain shape.

### Edge Cases

- **Grazing, parallel and inside-start rays** for picking: defined results (hit at distance 0 for inside starts where
  stated, nil for parallel misses); non-finite rays refused.
- **Colour stream with non-finite values or the wrong length:** refused before upload.
- **Steep terrain near the eye:** the clearance check samples around the eye, not only beneath it.
- **Very fast or tiny gestures:** clamped; a pinch to zero or infinity saturates at the limits.
- **Context loss:** colour streams and renderers rebuild from CPU state; nothing is saved from the GPU.
- **Reduce Motion toggled mid-ease:** the camera jumps to the target.
- **Damaged or newer saved state:** refused as before; the view in the saved state is clamped to the world's limits.

## Requirements *(mandatory)*

### Functional Requirements

**Generic additions in VisualCore (stories 2 and 3)**

- **FR-A12-201**: The mesh renderer and the depth pass MUST accept an optional per-vertex colour stream (one colour
  per vertex) multiplied into the lit colour; streams of the wrong length or with non-finite values MUST be refused;
  meshes drawn without a stream MUST draw exactly as before (G-MATERIALS).
- **FR-A12-202**: VisualCore's math module MUST offer ray intersection with boxes, spheres and triangles returning the
  nearest hit distance and surface normal, with defined grazing, parallel and inside-start behaviour and refusal of
  non-finite rays (G-PICKING).
- **FR-A12-203**: The new generic code MUST be documented, host-tested where it is pure, and recorded in the API
  baseline and the VisualCore README; existing digests and outputs MUST NOT change.

**The world's camera (story 1, G-CAMERA)**

- **FR-A12-210**: Each world MUST define its camera limits (pitch, distance, target) and a clearance; every orbit,
  zoom or reset MUST leave the camera within the limits and the eye at least the clearance above the terrain sampled
  around it.
- **FR-A12-211**: Drag MUST orbit and pinch MUST zoom; each MUST have a native control alternative.
- **FR-A12-212**: View changes MUST ease over a bounded time unless Reduce Motion is on, in which case they MUST be
  direct; easing MUST never change the saved state beyond the target view.
- **FR-A12-213**: The spoken view description MUST update at most once per second.

**Colour, picking and detail (stories 2–4)**

- **FR-A12-220**: Each world's terrain MUST be coloured per vertex from its palette by height (sea or void, low land,
  high land) and drawn in one draw with the sea as before.
- **FR-A12-221**: A tap MUST resolve to a ground point on the terrain or a miss, spoken, without changing the world.
- **FR-A12-222**: Each preset MUST exist at three detail levels (full, half and quarter resolution) whose meshes
  validate with all indices in bounds; the experience MUST declare three quality levels mapped to them; a level change
  MUST NOT change the world.

### Key Entities

- **Camera limits**: pitch range, distance range, target height, clearance.
- **Ray hit**: distance, point, normal.
- **Detail level**: 0 full, 1 half, 2 quarter resolution.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A12-201**: Over a sweep of at least 24 yaw × 8 pitch × 4 distance views per preset, 100 % stay within limits
  and keep the clearance.
- **SC-A12-202**: Ray intersection matches analytic answers within 1e-9 for all tested box, sphere and triangle cases.
- **SC-A12-203**: 100 % of the 27 detail meshes (3 presets × 3 seeds × 3 levels) validate with all indices in bounds.
- **SC-A12-204**: Coloured regions match their lit palette colours within ±8 of 255 per channel; meshes without
  colours are pixel-identical to before.
- **SC-A12-205**: Every camera gesture has a control alternative (0 missing); the runner's nine scenarios pass on
  iOS 27; every test runs in under 10 s.

## Assumptions

- The orbit camera and its bounds, the height-field sampler of A12-P01, the mesh renderer, the depth pass, gesture
  recognizers and the gesture-alternative check exist and are reused.
- One light direction stays fixed in this phase (light adjustment is A12-P03).

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 MVP: orbit camera with constrained zoom and comfortable control | FR-A12-210–213, US1 |
| Regression fixture: all LOD indices in bounds | FR-A12-222, SC-A12-203, US4 |
| EGL/context ownership in the VisualCore host | FR-A12-201, 220 |
| Brainstorm: camera and navigation, lighting, materials and assets | FR-A12-201, 210–213, 220 |
| Manual algorithm decisions 3–4 (separate picking geometry; near/far and no camera penetration) | FR-A12-202, 210, 221 |
| Contract gaps G-MATERIALS, G-PICKING, G-CAMERA | FR-A12-201–203, 210–213 |

## Negative Requirements

- No textures or artwork; no network; no second renderer or EGL path; no props, light adjustment or saved worlds in
  this phase; no camera motion that changes the world.
