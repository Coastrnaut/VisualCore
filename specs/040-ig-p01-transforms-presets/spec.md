# Feature Specification: Infinite Geometry — Phase 01 Geometry transforms and presets

**Feature Branch**: `040-ig-p01-transforms-presets` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A05-P01 (legacy ledger) · ID namespace FR-A05-1##, SC-A05-1##, T-A05-1##

**Input**: User description: archived manual `apps/05-infinite-geometry.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** the experience's domain and experience targets, its product, its registration, the app's
  link to it and its scenario manifest land together (the experience package check requires it). It is registered as a
  candidate: openable by the verification runner and in debug builds, hidden from people until X-A05.
- **Phase gates (manual §9 Phase 01):** MVP — at least two 2D tiling modes and one 3D procedural composition; regression
  fixture — symmetry order one is the identity and higher orders repeat correctly; the experience never owns the
  graphics context (the host does).
- **Reuse (A05-P00 contract):** gap G-SYMMETRY (point-group and wallpaper symmetry) is built in VisualCore's math module
  with documentation, the public-API baseline, tests and the reference regression. 2D compositions are drawn with the
  existing 2D primitive renderer; the 3D composition is built with the R02-F05 mesh compiler and drawn with the existing
  mesh renderer. The shader kaleidoscope is Phase 02; camera bounds are Phase 03.
- **Owner rulings of 2026-11-13:** short tests; system accessibility audits wait for the device campaign; independent
  files go to parallel agents.

## Clarifications

### Session 2026-11-13

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`SeededRandom` (VisualCoreSimulation) is the seeded generator; `Palette.builtIns` (VisualCoreParameters) has six
palettes; `ExperienceOutcome(code:)` is how A04 gives the completion scenario its outcome (`scene-built`); the 2D
primitive tree supports polygons (at most `Primitive.maxPolygonPoints` points) and the R02-F05 compiler builds closed
revolved meshes with a default budget.

- Q: What is the motif and how is it seeded? → A: A convex polygon of 3–7 points inside the group's fundamental region,
  drawn from `SeededRandom(seed)`; reseed advances the seed by a fixed step. The motif is the only seeded element, so the
  same preset and seed always give the same composition.
- Q: What bounds a 2D composition? → A: The view is the square −1…1 in both axes divided by the scale; repetitions
  (1…12) are the lattice rings around the centre for tilings and the concentric motif rings for the kaleidoscope; a
  composition holds at most 2,048 polygons — a build that would exceed it is refused as a budget error (never truncated).
- Q: What is the 3D composition? → A: `order` copies (1…24) of a seeded revolved "petal" (a profile of 5–9 points revolved
  with 24 segments) placed by rotation about the vertical axis at radius 1.5 and concatenated into one mesh; each copy is
  closed, so the whole mesh validates closed; it must fit the R02-F05 default budget.
- Q: How are palettes chosen? → A: By index into `Palette.builtIns` (0…5); polygon colours sample the palette by image
  index, so colour never depends on the GPU.
- Q: What outcome does the completion scenario reach? → A: `composition-built`, reported once the current composition has
  been built from a validated preset (true after preparation and after every accepted change); a refused action keeps
  the previous outcome.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Explore a symmetric composition from a preset (Priority: P1) 🎯

A person opens Infinite Geometry and picks one of the curated presets — a square tiling, a hexagonal tiling, a
kaleidoscope, or a 3D composition — and sees it drawn at once.

**Why this priority**: the MVP of the phase: two 2D tiling modes and one 3D procedural composition.

**Independent Test**: open each preset through the real session and check the drawn picture is non-blank and matches
the preset's kind; check the composition is identical for the same preset.

**Acceptance Scenarios**:

1. **Given** the experience, **When** it opens, **Then** the default preset is drawn in the first frame.
2. **Given** each of the curated presets, **When** it is selected, **Then** its composition is drawn: square tiling,
   hexagonal tiling, kaleidoscope, 3D composition.
3. **Given** the same preset twice, **When** it is built, **Then** the composition is identical (deterministic).

---

### User Story 2 - Change symmetry, repetitions, scale and palette (Priority: P1)

The person changes the symmetry order, the number of repetitions, the scale and the palette, and the composition
follows; invalid values are refused without changing anything.

**Why this priority**: the core controls of the manual's feature 03 and the regression fixture.

**Independent Test**: apply each control with valid and invalid values; check the state and the drawn composition.

**Acceptance Scenarios**:

1. **Given** symmetry order 1, **When** the composition is built, **Then** the motif appears exactly once (identity).
2. **Given** symmetry order n (2…24), **When** it is built, **Then** the motif repeats n times by rotation (2n with
   mirrors) and the n images are equal up to the rotation.
3. **Given** a value out of range or not a number, **When** it is applied, **Then** it is refused with a reason and the
   state is unchanged.
4. **Given** reseed, **When** it is applied, **Then** the motif's shape changes deterministically for the new seed.

---

### User Story 3 - The experience behaves like every experience (Priority: P2)

Saving and restoring, resetting, suspending and resuming, leaving and re-entering, and cancelling preparation all work
through the shared experience host, verified on both simulator runtimes.

**Independent Test**: the nine standard scenarios through the verification runner on both runtimes.

**Acceptance Scenarios**:

1. **Given** the nine scenarios, **When** the runner runs them, **Then** all pass on iOS 27.2 and 26.5.
2. **Given** a person's launch without the debug candidates switch, **When** the catalog is shown, **Then** Infinite
   Geometry is not listed.

---

### User Story 4 - Symmetry is a reusable framework capability (Priority: P2)

Other experiences and games can use the same symmetry transforms (rotation and mirror groups, square and hexagonal
lattices) from VisualCore, documented and tested.

**Independent Test**: the framework's math tests, the public-API baseline and the reference regression.

**Acceptance Scenarios**:

1. **Given** the symmetry transforms, **When** their tests run, **Then** identity, orbit sizes, folding and periodicity
   hold for every order 1…24 and both lattices.
2. **Given** the change to VisualCore, **When** the reference regression runs, **Then** 7 of 7 steps pass.

### Edge Cases

- **Order out of range (0, 25, negative, non-integer):** refused with a reason; the state is unchanged.
- **Repetitions beyond the bound:** refused; the composition never exceeds its element budget.
- **Scale 0, negative, infinite or NaN:** refused.
- **Unknown palette or preset index:** refused.
- **Point on a mirror line or at the centre:** folding is defined and stays on the line; the centre maps to itself.
- **Reduce Motion and Reduce Flashing:** nothing animates or flashes in this phase (compositions are static); later
  phases that animate must honour both.
- **Graphics context recreated:** the composition is rebuilt from the state; nothing is lost.
- **Restored state of a newer version:** refused by the shared migration chain; the session reports it.

## Requirements *(mandatory)*

### Functional Requirements

**Symmetry (story 4)**
- **FR-A05-101**: VisualCore MUST provide point-group symmetry: cyclic groups of order n and dihedral groups of order n
  (n = 1…24), giving the images of a point and folding a point into the fundamental region.
- **FR-A05-102**: VisualCore MUST provide two wallpaper lattices — square with 4-fold rotations and mirrors, hexagonal
  with 6-fold rotations and mirrors — giving the images of a point within a bounded region and folding a point into
  the fundamental region.
- **FR-A05-103**: Order 1 MUST be the identity; images MUST repeat with the group's period; folding MUST be idempotent
  and map every image of a point to the same folded point.
- **FR-A05-104**: The symmetry types MUST be documented, in the public-API baseline, and followed by the reference
  regression.

**Presets and compositions (stories 1–2)**
- **FR-A05-110**: The experience MUST offer at least four curated presets: square tiling, hexagonal tiling,
  kaleidoscope, 3D composition.
- **FR-A05-111**: A preset MUST hold its kind, symmetry order, repetitions, scale, palette, seed and schema version, and
  MUST be validated on entry (out-of-range and non-finite values refused).
- **FR-A05-112**: A 2D composition MUST be the motif's images under the preset's symmetry within a bounded view, at most
  2,048 polygons (more is refused, never truncated); a 3D composition MUST be a closed, valid mesh of `order` revolved
  copies within the R02-F05 default budget.
- **FR-A05-113**: Compositions MUST be deterministic for the preset and seed and MUST NOT depend on the GPU or the clock.

**Controls and state (story 2)**
- **FR-A05-120**: The experience MUST accept: select preset, set symmetry order, set repetitions, set scale, set
  palette, reseed; each validated; invalid actions refused with a reason and no state change. The symmetry order applies
  to the kaleidoscope and the 3D composition; the tilings have their lattice's fixed symmetry, so setting an order on a
  tiling is refused (`a05.order-fixed-by-lattice`).
- **FR-A05-121**: Every control MUST have an accessible label and a native control; the canvas MUST have a spoken
  description naming the preset, kind and symmetry order.

**Experience behaviour (story 3)**
- **FR-A05-130**: The experience MUST pass the nine standard scenarios on both simulator runtimes through the shared
  host (save/restore to the same digest, reset, suspend/resume, teardown/re-entry, cancel preparation, rejection,
  completion — outcome `composition-built`).
- **FR-A05-131**: It MUST be registered as a candidate (hidden from people until X-A05) and linked by the one app, with
  all four targets and its product.
- **FR-A05-132**: It MUST draw only through the host (no context, no second renderer, no ProjectM, no network, no
  imported assets).

### Key Entities

- **Symmetry group**: kind (cyclic, dihedral, square lattice, hexagonal lattice), order.
- **Geometry preset**: kind (squareTiling, hexTiling, kaleidoscope, solid), symmetry order, repetitions, scale, palette,
  seed, schema version.
- **Composition**: 2D polygons with colours, or a 3D mesh; built from a preset.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A05-101**: For every order 1…24 and both lattices, the symmetry tests pass: order 1 gives 1 image; cyclic order n
  gives n images; dihedral gives 2n; folding is idempotent in 100% of 1,000 sampled points per group.
- **SC-A05-102**: The four presets build compositions that are non-empty, within budget and identical across two builds
  (equal digests) in 4 of 4 cases; the 3D composition validates closed with 0 problems.
- **SC-A05-103**: Each control's valid value changes the state and each invalid value is refused with the state digest
  unchanged (100% of checks).
- **SC-A05-104**: The nine scenarios pass on iOS 27.2 and 26.5 (18 of 18 records).
- **SC-A05-105**: The reference regression passes 7 of 7; the public-API baseline lists the symmetry types.
- **SC-A05-106**: Every new unit test finishes in under 10 seconds.

## Assumptions

- R02-F05 (mesh compiler) and the existing 2D primitive renderer and mesh renderer are used unchanged.
- Presets are curated in code; saving named presets is Phase 04.

## Traceability

| Source | Requirement |
|---|---|
| MVP: two 2D tiling modes and one 3D composition | FR-A05-110, 112, US1 |
| Fixture: order one is identity; higher orders repeat | FR-A05-103, SC-A05-101 |
| Gate: EGL ownership in the host | FR-A05-132 |
| Feature 03: symmetry, repetitions, scale, palette | FR-A05-120, US2 |
| Feature 04 (part): deterministic presets | FR-A05-111, 113 |
| Gap G-SYMMETRY (A05-P00 contract) | FR-A05-101–104 |
