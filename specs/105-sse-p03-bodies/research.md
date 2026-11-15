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

## As built (2026-11-15)

- **Far plane, true-relative:** d + 140 (first written d + 70). At d + 70 the star sphere at 0.9 × far would come
  nearer than the farthest bodies once d > 20; at d + 140 it lies at 0.9 · d + 126, beyond every body (at most d + 61)
  for every camera distance used. `StarDepthTests` proves it for every focus, zoom step and four dates in both modes.
- **Tilt:** every body's sphere is tilted by its catalog axial tilt about the scene x axis, so Saturn's bands meet its
  ring plane (Uranus shows near-vertical bands); the pole azimuth is not modelled.
- **Orbit tubes:** radius 0.04 (enhanced) and 0.1 (true-relative, about 0.7 px at the overview).
- **Renderers:** 37 (bodies, rings, both orbit sets, stars, markers, Saturn's ring) are made together and released
  together, as A14-P01 and A14-P02 require.
- **Flight clearance:** the eye is pushed radially out of each clearance sphere for up to 4 passes; where clearances
  overlap (the Sun's 2.65 and Mercury's about 0.7 in the enhanced mode) not every clearance may hold, but the eye
  always stays outside every drawn radius, which is what SC-A14-303 requires and `FocusFlightTests` checks.
- **Ring profile:** extra profile points 100 km outside each Cassini edge keep the dark band sharp.
- **Draw order and probes:** the stars are drawn last; the background probe tries up to eight positions and uses the
  first that misses every body, ring, marker, star and orbit tube.
