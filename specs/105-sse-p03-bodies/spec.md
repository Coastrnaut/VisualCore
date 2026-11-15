# Feature Specification: Solar System Explorer — Phase 03 Camera and 3D body rendering

**Feature Branch**: `105-sse-p03-bodies` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A14-P03 (legacy ledger) · ID namespace FR-A14-3##, SC-A14-3##, T-A14-3##

**Input**: User description: archived manual `apps/14-solar-system-explorer.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — the bodies drawn as recognisable 3D worlds from a camera that can focus
  any of them; regression fixture — focus never crosses a body or the near plane and the scale modes keep their
  stated ratios; graphics context ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/solar-system-explorer/visualcore-contract.json`): G-BODIES (rows M06, M07,
  M09, M13, M21, M23) — app-local over the mesh renderer, the noise and the orbit camera: procedural surfaces without
  seams or pole pinches, Saturn's rings, the emissive Sun, the starfield, the true-relative and visibility-enhanced
  scale modes with their label, camera-relative drawing and an eased focus flight that never crosses the near plane.
  Text labels placed on the canvas at projected body positions share the caption overlay of the guided tours and move
  to A14-P04 (G-TOURS); the native body list and the spoken description name every body meanwhile.
- **Experience:** the orbit view of A14-P02 gains procedural surfaces, rings, a starfield, a scale-mode switch and an
  eased focus flight; play, pause and rate, tours and saved view state stay with A14-P04.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A14; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
VisualCoreScenes has only 2D gradient noise (`GradientNoise2D`, `FractalNoise2D`; sampling it by longitude and latitude
seams and pinches, contract row M06); `Mesh` exposes public `positions`, `normals`, `uvs`, `indices`;
`Mesh.revolution(profile:segments:)` and `Mesh.uvSphere(segments:rings:radius:)` exist; `MeshRenderer` always culls
back faces (`GL_CULL_FACE`, `GL_BACK`, MeshRenderer.swift); `OrbitCamera` has public `near` and `far`; the experience's
`make(id:storage:reduceMotion:…)` already receives Reduce Motion and ignores it (no motion until now).

- Q: How are seam-free surfaces made, and does VisualCore gain a 3D noise? → A: App-local `SphereNoise` in
  SolarSystemExplorerCore: seeded 3D value noise (integer lattice hashed with SplitMix64, smoothstep trilinear
  interpolation, 4 octaves, lacunarity 2, gain 0.5) evaluated at each vertex's unit direction, so the duplicated seam
  vertices and the pole vertices get identical colours. No VisualCore change: one consumer, recorded in the contract
  (II-a not triggered). Spheres are `uvSphere(segments: 48, rings: 24)`; per-vertex colours from a `SurfaceRecipe` per
  body: the Sun (emissive yellow-orange, ambient 1, granulation ±8 %), Mercury (grey
  terrain), Venus (pale yellow haze), Earth (ocean blue below noise 0.52, land green-brown above, white caps where
  |sin latitude| > 0.88), Mars (rust with dark patches), Jupiter and Saturn (latitude bands of sin(latitude · k)
  perturbed by noise; Jupiter 9 bands, Saturn 7 paler bands), Uranus (cyan, faint bands), Neptune (deep blue, faint
  bands). Seed of body i is 0xA14_0000 + i. The surface digest is the stable hash of the colour array.
- Q: Where do Saturn's ring numbers come from and how is the ring drawn when back faces are culled? → A: Main rings
  from the C ring's inner edge 74,500 km to the A ring's outer edge 136,775 km (NASA NSSDCA "Saturnian Rings Fact
  Sheet", nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html, public domain, epoch J2000.0, km), recorded as
  source records `ring-inner-radius` and `ring-outer-radius` and audited. The ring mesh is a flat annulus from
  `Mesh.revolution` (64 segments) plus a copy with reversed winding and flipped normals, so both faces draw; colour
  pale tan with ambient 0.7 and the Cassini division as a darker band at 117,580–122,170 km (same fact sheet).
  Tilted about the scene x axis by Saturn's catalog axial tilt (26.73°); the pole's azimuth is not modelled (stated
  approximation). In the enhanced mode the ring radii scale with Saturn's display radius.
- Q: What do the two scale modes map, and how are tiny bodies found? → A: Enhanced (mode 0, default): the A14-P02
  mapping (4·√r) and display radii, label "Distances and sizes not to scale". True-relative (mode 1): one linear scale,
  2 scene units per AU for both positions and radii (radius km ÷ 149,597,870.7 × 2; Neptune at ≈ 60, the Sun's radius
  ≈ 0.0093), label "Distances and sizes to one scale"; overview distance 120 × 1.25^−zoom, zoom steps −1…12 as in A14-P02.
  A body whose drawn radius is under 2 px gets a camera-facing marker ring of 6 px radius in its palette colour;
  markers never change the drawn body. The mode is state (schema 3, `scaleMode` 0/1, action `scale.mode [0…1]`, a
  non-whole value refused `a14.invalid-choice`), migration 2 → 3 adds mode 0.
- Q: How does the focus flight work without breaking determinism? → A: The flight is presentation only: the core's
  state changes in one step (focus = selection), and the presenter eases its drawn camera from the previous view to
  the new one over 30 drawn frames (smoothstep on the target position, distance interpolated in log space, yaw and
  pitch from the state). If an eased eye would come within a body's clearance (3 × drawn radius + 0.5 × near), it is
  pushed out radially to the clearance. Reduce Motion (passed at make) cuts in one frame. A new focus during a flight
  starts from the current drawn eye. The pure `FocusFlight` function is tested for all 72 ordered pairs in both modes.
- Q: What near and far planes and what precision bound apply? → A: Enhanced: near 0.5, far 200 (A14-P02). True-relative:
  near = max(1e-4, 0.05 × camera distance), far = camera distance + 70. Model matrices are built from positions minus
  the camera target in double precision before conversion to single precision; the test converts every body's
  camera-relative position to Float and back for both modes, every focus and zoom steps −1, 0 and 12, and bounds the
  error by 0.1 pixel at a 2,000-pixel-high canvas with a 60° field of view (pixel size 2 · d · tan 30° / 2,000 at camera
  distance d).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The bodies look like distinct worlds (Priority: P1) 🎯

A person sees the Sun glowing and each planet with its own procedural surface (bands for the giants, mottled terrain
for the rocky planets), Saturn with its rings, and a starfield behind them — all drawn in code, the same on every run.

**Why this priority**: the phase's MVP ("3D body rendering") and the manual's "procedural surfaces" override.

**Independent Test**: draw each body; compare its surface digest across runs; inspect the date line and the poles.

**Acceptance Scenarios**:

1. **Given** any body, **When** its surface is generated twice, **Then** both are identical, and the surface has no
   visible seam where longitude wraps and no pinch at the poles.
2. **Given** Saturn, **When** drawn, **Then** its rings surround it in its equatorial plane, tilted by its axial tilt.
3. **Given** the view, **When** drawn, **Then** a fixed starfield lies behind every body and never in front of one.

---

### User Story 2 - Choose how size and distance are shown (Priority: P1)

A person switches between a visibility-enhanced mode (bodies enlarged, distances compressed, labelled not to scale)
and a true-relative mode (sizes and distances in one scale, with every body still findable), and always sees and
hears which mode is on.

**Why this priority**: the manual's separate scale modes and the truthful-labelling rule.

**Independent Test**: switch modes; measure drawn ratios; read the label and the spoken description.

**Acceptance Scenarios**:

1. **Given** the true-relative mode, **When** drawn, **Then** every body's drawn radius and distance keep the catalog's
   ratios within a stated tolerance, and a body smaller than a few pixels is marked so it can still be found.
2. **Given** the visibility-enhanced mode, **When** drawn or described, **Then** it is labelled "not to scale".
3. **Given** either mode, **When** switched, **Then** the active mode is shown and announced.

---

### User Story 3 - Fly to a body without passing through it (Priority: P1)

A person focuses a body; the camera glides to it over a short, eased flight that never passes through any body or
in front of the near plane; with Reduce Motion the view cuts straight to the focused body.

**Why this priority**: the phase's regression fixture (focus and near clip).

**Independent Test**: focus every body from every other; sample the flight; check clearances.

**Acceptance Scenarios**:

1. **Given** any two bodies, **When** focus moves from one to the other, **Then** at every sampled step the eye stays
   outside every body and the focused body stays inside the visible depth range.
2. **Given** Reduce Motion, **When** a body is focused, **Then** the view changes in one step.
3. **Given** a flight in progress, **When** another body is chosen, **Then** the flight restarts from the current view.

---

### User Story 4 - Precision holds at every distance (Priority: P2)

The owner sees that bodies far from the origin (Neptune at 30 AU in the true-relative mode) are drawn without
jitter, because positions are kept in double precision and drawn relative to the camera.

**Why this priority**: the manual's algorithm decision 2 (double precision, camera-relative for the GPU).

**Independent Test**: compute drawn positions for every body in both modes; bound the single-precision error.

**Acceptance Scenarios**:

1. **Given** any body in either mode, **When** converted for drawing, **Then** its position error is below a stated
   fraction of a pixel.

### Edge Cases

- **Date line and poles:** surfaces are sampled from the direction on the sphere, not from longitude and latitude.
- **Mercury in the true-relative mode:** smaller than a pixel from the overview; a marker keeps it findable.
- **Focus during a flight:** the new flight starts from the current eye, not the old target.
- **Context recreation:** surfaces and rings rebuild and the image is unchanged within a pixel tolerance.
- **The Sun focused at close zoom:** the eye stays outside the Sun's drawn radius in both modes.

## Requirements *(mandatory)*

### Functional Requirements

**Bodies (story 1)**

- **FR-A14-301**: Each body MUST have a procedural surface generated in code from a seeded, seam-free function of the
  direction on the sphere, with a palette per body (bands for the giants, terrain for the rocky planets, a bright
  emissive Sun); the same seed gives the same surface digest.
- **FR-A14-302**: Saturn MUST have rings in its equatorial plane tilted by its catalog axial tilt, with inner and outer
  radii recorded with source, units and license.
- **FR-A14-303**: A seeded starfield MUST lie behind every body at a fixed far distance and never occlude a body.

**Scale modes (story 2)**

- **FR-A14-310**: Two scale modes MUST be offered: visibility-enhanced (the A14-P02 mapping and display radii) and
  true-relative (one linear scale for radii and distances, both from the catalog), switched by an action and part of
  the state.
- **FR-A14-311**: In the true-relative mode a body drawn smaller than a stated pixel size MUST get a marker; the drawn
  radii and distances MUST keep the catalog's ratios within a stated tolerance.
- **FR-A14-312**: The active mode MUST be shown and spoken; the enhanced mode is always labelled "not to scale".

**Camera (stories 3, 4)**

- **FR-A14-320**: Focusing a body MUST start an eased flight of a stated number of host steps from the current eye to
  the new view; Reduce Motion makes it a single step; a new focus during a flight restarts it from the current eye.
- **FR-A14-321**: At every step of a flight the eye MUST stay outside every body's drawn radius and the focused body
  inside the near and far planes chosen for the active mode.
- **FR-A14-322**: Positions MUST be kept in double precision and converted for drawing relative to the camera target;
  the conversion error MUST be below a stated fraction of a pixel for every body in both modes.

**Integration**

- **FR-A14-330**: The scenario manifest MUST be updated (state schema 3 with `scaleMode` and migration from 2) and pass the runner on
  iOS 27; the contract closes G-BODIES with the label placement moved to G-TOURS.

### Key Entities

- **Surface recipe**: body, seed, palette (colours and bands or terrain thresholds), noise frequency.
- **Ring record**: Saturn, inner and outer radius (km), source, units, license.
- **Scale mode**: enhanced or true-relative; mapping of positions and radii; near and far planes.
- **Focus flight** (presentation only): from-view, to-view, frame index of 30; Reduce Motion cuts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A14-301**: 100 % of surfaces are identical across two generations and differ between bodies; the largest colour
  jump across the date line is no larger than the largest jump between neighbouring vertices elsewhere.
- **SC-A14-302**: In the true-relative mode every ratio of drawn radius to drawn distance matches the catalog within
  0.1 %; 100 % of enhanced-mode descriptions say "not to scale".
- **SC-A14-303**: For all 72 ordered pairs of bodies, every sampled flight step keeps the eye outside every body and
  the focused body within the depth range.
- **SC-A14-304**: The largest single-precision position error of any body in either mode is below 0.1 pixel.
- **SC-A14-305**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The catalog, orbit model, date and camera of A14-P01 and A14-P02 exist; VisualCore's sphere, revolution and tube
  meshes, per-vertex colours, depth pass, orbit camera and ray-sphere tests exist (contract rows M01, M06, M07).
- Saturn's ring radii come from the NASA NSSDCA Saturnian Rings Fact Sheet (public domain).

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 MVP: 3D body rendering from a focusable camera | FR-A14-301–303, 320 |
| Regression fixture: focus never crosses a body or the near plane | FR-A14-321, SC-A14-303 |
| v0.1 feature 1: procedural surfaces (textures replaced) | FR-A14-301, 302 |
| v0.1 feature 4: true-relative and visibility-enhanced modes | FR-A14-310–312 |
| Algorithm decision 2: double precision, camera-relative for the GPU | FR-A14-322 |
| Contract gap G-BODIES (M06, M07, M09, M13, M21, M23) | FR-A14-301–330 |

## Negative Requirements

- No textures, images or imported models; no network; no on-canvas text labels yet (A14-P04); no play/pause or tours;
  no claim that the enhanced mode is to scale; no flashing or rapid motion.
