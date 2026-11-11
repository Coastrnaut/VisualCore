# Feature Specification: Fractal Explorer — Phase 01 Complex-plane math and fixtures

**Feature Branch**: `026-fe-p01-complex-math` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A03-P01 · ID namespace FR-A03-1##, SC-A03-1##, T-A03-1##

**Input**: User description: archived manual `apps/03-fractal-explorer.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- The phase gates:
  - MVP: Mandelbrot and Julia modes with accessible mode explanations;
  - regression fixture: known points (the Mandelbrot origin is interior, c = 2 is exterior, known Julia samples);
  - EGL and context ownership stays solely in the VisualCore host.
- This phase closes two gaps:
  - G-VIEWPORT in VisualCore: a generic double-precision complex-plane viewport with anchored pinch and aspect
    handling;
  - G-FRACTAL in the app: the escape-time CPU reference.
- GPU shaders and the precision probe are Phase 02.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2); the recommended option was chosen in each
case.

- Q: What exactly is the escape rule, and what counts do the exterior fixtures expect? → A: Iterate z ← z² + c. After
  step n (n = 1, 2, …), the point escapes when |z|² > R² (default R = 2). The count is that n. Points still bounded
  after the cap are interior. The expected counts are therefore c = 2 → 2 (z₁ = 2 is not > 2; z₂ = 6), c = 1+i → 2,
  and c = −2.1 → 1. The smooth value is n + 1 − log₂(log|zₙ|), computed in double. The anchored-pinch and fixture
  tolerances are as in the success criteria.
- Q: What is the VisualCore viewport called and where does it live? → A: `PlaneViewport` in VisualCoreMath (pure,
  Double, rule R2). The generic name fits any 2D-plane app, and `Camera2D` stays unchanged. It provides:
  - `center` as `Vec2` in plane units, `unitsPerPoint`, and `size` in points;
  - `plane(fromScreen:)` and `screen(fromPlane:)`, with y down on screen and up in the plane;
  - `pinched(by:anchor:)`, `panned(by:)` and `resized(to:)`;
  - `scale` limits `minUnitsPerPoint` (1e-15) and `maxUnitsPerPoint` (1e3), with `wasClamped`.
- Q: Where does app domain code live? → A: A local Swift package `Apps/FractalExplorer/FractalExplorerCore` (the A02
  layout), with `FractalMath` (the escape iteration), `FractalState` and `FractalExplanations` (mode texts).
  Host-tested with `swift test`, and linked by the app.
- Q: How is the CPU preview bounded, and how does it avoid blocking the UI? → A: At most 160 × 160 samples, iteration
  cap ≤ 10,000, computed in a detached task. Each request carries an identifier; a result for an older identifier is
  dropped. Colors come from a fixed grayscale ramp of the smooth value, with black for interior points. The palette
  system is Phase 02/03.
- Q: What are the defaults? → A: Mandelbrot: center (−0.5, 0), framed so the plane width −2.5…1.5 fits the shorter
  side. Julia: seed c = −0.8 + 0.156i, center 0, width 3.2. Iteration cap 200, escape radius 2.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose Mandelbrot or Julia and understand what each shows (Priority: P1) 🎯

A math learner opens the explorer, sees the Mandelbrot set, switches to a Julia set, and can read (or hear) a short
explanation of what each mode draws and how they relate.

**Why this priority**: The phase's MVP gate (v0.1 feature 01).

**Independent Test**: Open the explorer, switch modes with the control, and read the explanation and the picture's
spoken description in each mode. Both work without any gesture.

**Acceptance Scenarios**:

1. **Given** the explorer, **When** it opens, **Then** it shows the Mandelbrot set framed to the whole set. A mode
   control offers Mandelbrot and Julia, and a short explanation of the current mode is visible and spoken.
2. **Given** Mandelbrot mode, **When** the person picks Julia, **Then** the picture changes to the Julia set for the
   current seed c. The explanation says that each point of the Mandelbrot set is a seed whose Julia set is
   connected.
3. **Given** either mode, **When** VoiceOver reads the picture, **Then** it hears the mode, the center, the zoom and,
   for Julia, the seed.

---

### User Story 2 - Correct, testable fractal math (Priority: P1)

The maintainer needs the escape-time rules to be right and checkable without a GPU, so the Phase 02 shaders have a
reference to match.

**Why this priority**: The manual's Phase 01 regression fixture and the A03 rule (formulas with a CPU reference).

**Independent Test**: Run the host tests: known interior and exterior points, known Julia samples, a smooth escape
value, and NaN/Inf guards.

**Acceptance Scenarios**:

1. **Given** the Mandelbrot iteration, **When** c = 0, −1 or −0.1+0.1i is tested, **Then** each stays bounded for the
   whole iteration cap (interior). **When** c = 2, 1+i or −2.1 is tested, **Then** each escapes within a few
   iterations (exterior). The escape counts are exact.
2. **Given** the Julia iteration with c = 0, **When** points |z| < 1 and |z| > 1 are tested, **Then** the inside
   points stay bounded and the outside points escape. With c = −1, z = 0 stays bounded.
3. **Given** any escaping point, **When** its smooth escape value is computed, **Then** it is finite and lies in
   [n, n + 1 + log₂(1/ln 2)] ≈ [n, n + 1.53] for escape count n with R = 2 and |c| ≤ 2.1. The bound is derived from
   log|zₙ| ∈ (ln 2, ln 6.41] (corrected in implementation; the first draft's [n−1, n+1] was wrong at |zₙ| just
   above 2). For points that never escape it is reported as interior.
4. **Given** a non-finite c, z or parameter, **When** it is iterated, **Then** it is rejected or treated as escaping
   at step 0. It never produces NaN output.

---

### User Story 3 - A precise, distortion-free view of the plane (Priority: P1)

Pinching and panning must keep the picture where the person's fingers are, and rotating or resizing the device must
not stretch the picture.

**Why this priority**: The manual's §11 fixtures 2 and 3. The camera math is reused by every 2D-plane app (G-VIEWPORT).

**Independent Test**: Host tests of the viewport: screen↔plane round trips, an anchored pinch, and aspect changes.

**Acceptance Scenarios**:

1. **Given** a viewport, **When** a screen point is mapped to the plane and back, **Then** it returns to the same
   screen point within 1e-9 points.
2. **Given** a pinch anchored at a screen point, **When** the scale changes by any factor in 1e−6…1e6, **Then** the
   plane point under the anchor stays fixed within 1e-12 relative.
3. **Given** a size or aspect change, **When** the viewport adapts, **Then** the center stays the same plane point,
   and a square of the plane remains square on screen.
4. **Given** a pan by a screen delta, **When** it is applied, **Then** the content moves exactly with the finger.

---

### User Story 4 - A first picture without a GPU dependency (Priority: P2)

The explorer shows a real (low-resolution) picture of the current mode computed from the CPU reference. This proves
the math end to end before Phase 02 replaces it with the GPU render, and it becomes Phase 02's comparison fixture.

**Why this priority**: "Validated render behavior" for this phase, without GPU work.

**Independent Test**: Open the explorer in each mode and compare known pixels of the preview with the CPU reference.

**Acceptance Scenarios**:

1. **Given** Mandelbrot mode, **When** the preview is computed, **Then** the pixel at the origin is the interior color,
   and the pixel at c = 2 is an exterior color. The preview is deterministic for the same view and parameters.
2. **Given** the preview is being computed, **When** the person switches modes, **Then** the stale result is
   discarded and the UI never blocks. The work is bounded by a fixed pixel and iteration budget.

### Edge Cases

- A zoom that would make units per point below about 1e-15 or non-finite is clamped, and the clamp is reported. This
  is the double-precision limit for the CPU viewport. The float32 shader limit is Phase 02.
- A size of zero (before layout): the viewport keeps its last valid size and maps nothing.
- An iteration cap outside 1…10,000: clamped. An escape radius below 2: raised to 2.
- A Julia seed outside |c| ≤ 2: allowed (most Julia sets are then dust), and the explanation says so.
- VoiceOver users and switch-control users: the mode control and the explanation work without the canvas.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A03-101**: The app MUST offer Mandelbrot and Julia modes through an accessible control.
  - Each mode has a short explanation (visible and spoken).
  - The picture has a spoken description with the mode, the center, the zoom and, for Julia, the seed. For example:
    "Mandelbrot set, centered at −0.5 + 0i, zoom 1×", or "Julia set for seed −0.8 + 0.156i, centered at 0 + 0i,
    zoom 1×". Coordinates use up to 6 significant digits. The zoom is relative to the default framing: a whole
    number below 10,000×, otherwise scientific notation (for example 2.5e7×).
- **FR-A03-102**: The app MUST compute the escape-time iteration z ← z² + c on the CPU:
  - Mandelbrot: z₀ = 0, c = the point;
  - Julia: z₀ = the point, c = the seed;
  - it returns the escape count within a cap, a smooth escape value, and an interior flag;
  - non-finite inputs never produce NaN output.
- **FR-A03-103**: Known-point fixtures MUST pass:
  - the Mandelbrot interior points 0, −1 and −0.1+0.1i;
  - the exterior points 2, 1+i and −2.1, with their exact escape counts;
  - the four Julia samples:
    - c = 0, z = 0.5: interior;
    - c = 0, z = 1.5: exterior, count 1 (z₁ = 2.25, |z₁|² = 5.0625 > 4);
    - c = −1, z = 0: interior (period 2);
    - c = −0.8+0.156i, z = 2: exterior, count 1.
- **FR-A03-104**: VisualCore MUST provide a generic double-precision complex-plane viewport (G-VIEWPORT), with
  tests, docs, the API baseline and the ProjectM regression. It has:
  - a center (re, im), units per point, and a view size in points;
  - screen↔plane mapping with y up in the plane;
  - an anchored pinch, a pan, and aspect-preserving resize;
  - a zoom clamp with a report.
- **FR-A03-105**: The app's fractal state MUST hold:
  - the mode;
  - the viewport;
  - the Julia seed;
  - the iteration cap (1…10,000, default 200) and the escape radius (≥ 2, default 2).

  All values are validated on input.
- **FR-A03-106**: The explorer MUST show a deterministic CPU-reference preview of the current view (bounded budget,
  off the main thread). It replaces stale results when the view changes, and creates no render host or GPU
  resources.
- **FR-A03-107**: The contract MUST record G-VIEWPORT and G-FRACTAL as closed, with their tests. The checks MUST pass
  (documented API, isolation, contract, fast checks), and the ProjectM regression MUST pass after the VisualCore
  addition.

### Key Entities

- **Complex-plane viewport** (VisualCore): center (re, im), units per point, view size (points), zoom limits.
- **Fractal state** (app): mode, viewport, Julia seed, iteration cap, escape radius.
- **Escape result** (app): escape count, smooth value, interior flag.
- **FractalPreview** (app; renamed from Preview, which collides with SwiftUI): width × height colors for a view and parameters, with a request identifier.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A03-101**: 100% of the known-point fixtures pass: 3 Mandelbrot interior, 3 Mandelbrot exterior with exact
  counts, and 4 Julia samples.
- **SC-A03-102**: Screen↔plane round trips are within 1e-9 points. An anchored pinch keeps the anchor within 1e-12
  relative over scale factors 1e−6…1e6. After 100 random resizes, the center and the square-pixel rule hold.
- **SC-A03-103**: Mode switching, the explanations and the spoken description work on both simulator runtimes, and
  the accessibility audit (default size and XXXL) finds no issues.
- **SC-A03-104**: The preview's origin pixel is interior and its c = 2 pixel exterior. Two computations of the same
  view are identical.
- **SC-A03-105**: API review, documented-API, isolation, contract, ProjectM regression (7/7) and the app and host
  tests on both runtimes all pass.

## Assumptions

- Smooth escape value: n + 1 − log₂(log|zₙ|), a common normalization. The exact palette mapping is Phase 02/03.
- The CPU preview is a reference and a fallback picture, not the product renderer. It is sized to stay under a fixed
  budget (for example 160 × 160 pixels at the current cap) and is replaced by the GPU render in Phase 02.
- No persistence in this phase. Bookmarks are Phase 03.
- Gestures on the canvas arrive in Phase 02/03 with the GPU view. This phase proves the gesture math in host tests.

## Traceability

| Source | Covered by |
|---|---|
| v0.1 feature 01 (Mandelbrot and Julia modes with explanations) | FR-A03-101, FR-A03-102, US1 |
| Manual Phase 01 fixture (known points) | FR-A03-103, SC-A03-101 |
| Manual §11 fixtures 2–3 (anchored zoom, aspect) | FR-A03-104, SC-A03-102 |
| Manual §6 algorithm decisions 1–2 (aspect mapping, escape with NaN guard) | FR-A03-102, FR-A03-104 |
| Manual §13 risk 3 (gesture drift; double on CPU) | FR-A03-104 |
| Journey 2 (switch Mandelbrot/Julia) | US1 |
| Gap register G-VIEWPORT, G-FRACTAL | FR-A03-104, FR-A03-102, FR-A03-107 |

## Negative Requirements

- No GPU rendering, render host or EGL in this phase; no second renderer ever.
- No claim of unlimited zoom; the CPU clamp is reported.
- No networking, permissions or persistence.
- No research-grade or precision claims in the explanations, which are educational.
