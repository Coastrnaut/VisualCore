# Research: A14-P03 (feature 105)

## D1 — Seam-free surfaces
- **Decision**: seeded 3D value noise at the unit direction (clarification Q1); colours per vertex on a 48 × 24 UV
  sphere. Duplicated seam vertices share a direction, so they share a colour; the pole rows collapse to one direction.
- **Alternatives**: 2D noise in longitude/latitude (seams, pinches — rejected); a VisualCore 3D noise (deferred: one
  consumer; recorded in the contract for reassessment); a cube-sphere (more geometry code for no visible gain).

## D2 — Rings
- **Decision**: NSSDCA Saturnian Rings Fact Sheet: C ring inner 74,500 km, A ring outer 136,775 km, Cassini division
  117,580–122,170 km; flat two-sided annulus (revolution + reversed copy) because back faces are always culled.

## D3 — Scale modes
- **Decision**: enhanced (A14-P02) and true-relative (2 units per AU for positions and radii); markers below 2 px.
- **Rationale**: one Double source of positions, two mappings; ratios testable exactly in the true mode.

## D4 — Focus flight
- **Decision**: presentation-only easing over 30 frames with clearance push-out; Reduce Motion cut; restart from the
  current drawn eye. Keeps the core deterministic and the digest independent of frame timing.

## D5 — Precision
- **Decision**: positions minus target in Double, then Float; bound 0.1 px at 2,000 px and 60° (clarification Q5).
