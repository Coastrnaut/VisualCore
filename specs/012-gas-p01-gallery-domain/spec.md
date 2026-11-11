# Feature Specification: Generative Art Studio — Phase 01 Gallery and domain contract

**Feature Branch**: `012-gas-p01-gallery-domain` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: A01-P01 · ID namespace FR-A01-1##, SC-A01-1##, T-A01-1##

**Input**: User description: archived manual `apps/01-generative-art-studio.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation). Canonical override: constitution 1.2.0 Principle II "Maximize reuse". Reusable logic
goes into VisualCore modules (gap register `docs/apps/generative-art-studio/visualcore-contract.json`). The app keeps
only product composition, content and one-off rules. Evidence is host and simulator only.

## User Scenarios & Testing *(mandatory)*

Users: casual makers and visual artists (manual §2 audiences), and the developers of the other 24 apps who reuse the
VisualCore pieces this phase adds.

### User Story 1 - Browse a gallery of four distinct scene families (Priority: P1) 🎯

A user opens the app and sees a gallery of four genuinely different procedural scene families: gradient noise,
raymarched shapes, geometric tiling and particles. Each family has a title, a description and at least one curated
preset. Choosing one shows that scene rendering live.

**Why this priority**: It is version 0.1 feature 01 and the first half of journey 1, and it is the vertical slice the
manual requires.

**Independent Test**: Launch the app, see four gallery entries, open each one, and see a rendered, non-blank scene with
its accessible description.

**Acceptance Scenarios**:

1. **Given** a fresh launch, **When** the gallery appears, **Then** it lists exactly four scene families. Each has a
   title, a one-line description, a preset count ≥ 1 and an accessibility label.
2. **Given** any family, **When** it is opened, **Then** its default preset renders live through the shared VisualCore
   render host, and the canvas has a spoken description of what it shows.
3. **Given** the four families, **When** each is rendered at the same seed and time, **Then** the images differ
   pairwise beyond a defined difference threshold (they are genuinely distinct).

---

### User Story 2 - A deterministic, versioned domain contract (Priority: P1)

A composition is pure data: scene family, seed, palette, parameter values and preview time. That data validates,
serializes, round-trips exactly, and always renders the same image for the same seed and explicit time.

**Why this priority**: It is the manual's regression-fixture gate. Journeys 2 and 3 and Phases 03–04 build on it.

**Independent Test**: Host tests for validation and round trips; simulator tests rendering the same document twice and
after a round trip, comparing images within tolerance.

**Acceptance Scenarios**:

1. **Given** a valid composition, **When** it is encoded and decoded, **Then** the result is equal, byte-for-byte
   stable in a canonical encoding, with the same parameter hash.
2. **Given** a composition with an out-of-range, NaN or unknown parameter, an unknown scene family or an unsupported
   schema version, **When** it is validated, **Then** it is rejected or clamped by a documented rule with a readable
   reason, never crashing or silently rendering garbage.
3. **Given** the same composition (seed and explicit time), **When** it is rendered twice, including once after a
   serialization round trip, **Then** the images match within the defined GPU tolerance.
4. **Given** two different seeds, **When** rendered, **Then** the images differ (the seed matters).

---

### User Story 3 - Reusable VisualCore building blocks (Priority: P2)

Other apps get the general pieces this slice needs as documented VisualCore modules rather than app code:

- parameter schemas, values, presets and palettes;
- loading shaders from a bundle;
- a shared GLSL include library (hash, noise, palettes, signed distances, sRGB);
- a full-screen parameterized shader scene;
- a SwiftUI render surface;
- image comparison for tests.

**Why this priority**: The owner's reuse rule. Without these, the next 24 apps would duplicate them.

**Independent Test**: Each new or extended module has its own package tests, public docs and an API-baseline entry. The
ProjectM regression still passes.

**Acceptance Scenarios**:

1. **Given** the new public API, **When** the public-API review runs, **Then** every new declaration is documented and
   the baseline is updated in the same change.
2. **Given** the VisualCore changes, **When** the reference regression runs, **Then** it passes as in Phase 00.

### Edge Cases

- A parameter value outside its range is clamped to the range. NaN or ±∞ rejects the document.
- A parameter missing from a document takes the schema default. An unknown parameter is dropped with a warning.
- An unknown palette id falls back to the family's default palette with a warning.
- A schema version newer than supported is rejected without modification. Older versions are migrated (none exist
  yet; the hook is tested).
- A scene shader fails to compile: the scene shows a readable error with file and line, and the gallery stays usable.
- Context loss while a scene is showing: the scene rebuilds from the document (CPU state) with no leaked resources.
- Seed 0 and the maximum seed (2^64−1) are valid and deterministic.
- Reduce Motion is on: scenes still render, at a slower animation rate (full reduced-motion behavior arrives in
  Phase 05).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A01-101**: The gallery MUST present exactly four scene families with these ids:
  - `gradient-noise`;
  - `raymarched-shapes`;
  - `geometric-tiling`;
  - `particles`.

  Each has a title, a description, an accessibility label and ≥ 1 curated preset.
- **FR-A01-102**: Opening a family MUST render its default preset live through the VisualCore render host. The app MUST
  NOT create EGL objects or its own GL lifecycle.
- **FR-A01-103**: The composition document MUST hold:
  - id;
  - schema version;
  - scene family id;
  - seed (unsigned 64-bit);
  - palette id;
  - parameter values by name;
  - preview time in seconds.

  It MUST validate on decode and encode canonically (sorted keys, stable number formatting).
- **FR-A01-104**: Parameter schemas MUST declare each parameter's name, unit, minimum, maximum, default and UI
  transform (linear or logarithmic). Validation clamps out-of-range values, rejects non-finite values, fills missing
  values with defaults and drops unknown names with a warning.
- **FR-A01-105**: A stable parameter hash MUST be computed from family, seed, palette and resolved parameter values. It
  is equal for equal compositions and differs when any of them changes. It is used later to cache thumbnails.
- **FR-A01-106**: Rendering a composition MUST depend only on the document and an explicit time (no wall clock and no
  unseeded randomness). Two renders of the same document and time match within the GPU tolerance.
- **FR-A01-107**: The four families MUST be pairwise visually distinct at the same seed and time: mean absolute
  channel difference ≥ 20/255 between every pair at a fixed size.
- **FR-A01-108**: These reusable pieces MUST live in VisualCore modules (Principle II):
  - parameter schemas, values, presets, palettes and the hash: new pure module `VisualCoreParameters`;
  - bundle shader loading and the shared GLSL include library: `VisualCoreRendering`;
  - a full-screen parameterized shader scene: `VisualCoreRendering`;
  - a SwiftUI render surface: `VisualCoreUI`;
  - RGBA image comparison: `VisualCoreTestSupport`, test-only.

  Each MUST have package tests and public docs, and the API baseline MUST be updated.
- **FR-A01-109**: After the VisualCore changes, the ProjectM reference regression MUST pass (same seven steps as the
  Phase 00 baseline), and the Showcase MUST still pass its tests (it migrates to the shared bundle loader).
- **FR-A01-110**: Scene shader errors MUST surface as a readable message with file and line on the scene screen. Context
  loss MUST rebuild the scene with zero leaked GPU resources.
- **FR-A01-111**: The app MUST stay offline, request no permissions and link no ProjectM module. Domain logic MUST be
  host-testable without a GPU.
- **FR-A01-112**: The gallery and scene screens MUST be accessible:
  - VoiceOver labels and hints for each family;
  - a spoken canvas description;
  - Dynamic Type for text;
  - no information conveyed by color alone.
- **FR-A01-113**: The VisualCore contract (`docs/apps/generative-art-studio/visualcore-contract.json`) MUST be updated:
  - closed gaps marked `available`, with new evidence;
  - the gaps' phases corrected.

  The contract check MUST pass.

### Key Entities

- **Scene family**: id, title, description, accessibility description, shader or renderer kind, parameter schema,
  default palette, presets.
- **Parameter schema / value set** (VisualCore): parameters with unit, range, default and transform; resolved values;
  warnings.
- **Palette** (VisualCore): id, name, ordered color stops in sRGB, interpolation in linear light.
- **Preset**: id, title, family, seed, palette, parameter values.
- **Composition (ArtDocument)**: id, schema version, family, seed, palette, parameters, preview time.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A01-101**: 4 of 4 families appear in the gallery and render non-blank: ≥ 2 distinct colors and mean luminance
  within 0.02–0.98 on both simulator runtimes.
- **SC-A01-102**: 100% of document round trips in the domain test set are equal and keep the same hash (≥ 50
  generated compositions, including edge seeds).
- **SC-A01-103**: The same document rendered twice, and after a round trip, matches within tolerance: ≥ 99% of
  channels within 2/255 and mean difference ≤ 0.5/255. This holds for all 4 families on both runtimes.
- **SC-A01-104**: 6 of 6 distinct family pairs differ by a mean absolute difference ≥ 20/255. Different seeds of the
  same family differ by mean ≥ 2/255.
- **SC-A01-105**: 0 leaked GPU resources after context loss and destroy for every family.
- **SC-A01-106**: The public-API review, the documented-API check for the app, the contract check, the ProjectM
  regression (7/7) and the Showcase tests all pass.

## Assumptions

- Interactive parameter controls, time scrub, saving, export and full reduced-motion behavior are Phases 02–05. This
  phase uses presets and default values.
- GPU tolerance figures come from the F07 ANGLE noise-floor measurements (simulator). Device tolerances are measured
  in campaign II.
- Thumbnails in the gallery may be static symbols or swatches in this phase. Rendered thumbnails need the still
  exporter (Phase 04).
