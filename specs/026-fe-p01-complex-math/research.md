# Research: Fractal Explorer — Phase 01

## R1. Viewport representation

- **Decision**: center plus units per point, both Double, with the size in points. A screen point (x, y) maps to the
  plane point (cx + (x − w/2)·u, cy − (y − h/2)·u).
- **Rationale**:
  - Units per point keeps pixels square at any aspect ratio.
  - Doubles give about 1e-15 relative resolution, so the clamp sits at 1e-15 units per point at a center of order 1.
- **Alternatives**: a min/max rectangle, which drifts under repeated aspect changes.

## R2. Anchored pinch

- **Decision**:
  1. Let the anchor's plane point be p.
  2. Set u′ = u / scale, clamped to the limits.
  3. Set the new center c′ = p − (anchor − mid) · u′, with the y flip.
- **Rationale**: p stays exactly under the anchor, up to rounding (spec SC-A03-102).

## R3. Escape iteration and smooth value

- **Decision**: iterate in Double; escape when |z|² > R²; the smooth value is n + 1 − log₂(log|zₙ|). A non-finite
  input gives escape at step 0 with a smooth value of 0.
- **Rationale**: this is the standard normalization, and it is continuous across iteration bands.
- **Note**: the fixtures use the exact counts derived in clarification 1.

## R4. Preview

- **Decision**: at most 160 × 160 samples, a detached task, request identifiers, and a grayscale ramp with black
  interior. The result is RGBA bytes turned into a `CGImage`.
- **Rationale**: it is deterministic and bounded, involves no GPU, and becomes the Phase 02 comparison fixture.
