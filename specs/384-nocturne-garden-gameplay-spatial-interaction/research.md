# Research: R02-G09-04

- **R1 Pick order.** Decision: lantern, then blooms (head box at z = 0.37 or projected foot/head centre within 22
  points; nearest to the eye), then the bed cell under the ray on z = 0. Rationale: the small targets (lantern, blooms)
  must win over the large bed; follows feature 374's "preview first, then pieces". Alternatives: bed first (rejected: a
  bloom could never be grabbed over its own shadow).
- **R2 Plant by tap.** Decision: a tap on a bed cell plants the panel's kind and size there. Rationale: planting is the
  most frequent action; one touch per move matches the move budget; undo makes mistakes cheap. Alternatives: tap to
  pick the cell then press Plant (rejected: two steps for the main action).
- **R3 Exact preview.** Decision: while a bloom is dragged, the would-be mask is computed with the kernel's own cell
  function (`NocturneGardenMask.union`) on a copy of the blooms, so the preview equals what the move would produce.
  Rationale: the design's "silhouette preview as exact diagnostic"; no approximation can disagree with the verdict.
- **R4 Two fingers.** Decision: a pinch when the first finger is on a bloom, otherwise orbit. Rationale: pinch scale is
  a bloom gesture; orbit stays available everywhere else. A second finger cancels any one-finger gesture, as in 374.
- **R5 Sun steps.** Decision: 48 points of vertical drag per elevation step, snapped to the level's allowed
  elevations. Rationale: four elevations fit a comfortable thumb travel on a phone.
- **R6 Orbit.** Decision: yaw ±35°, pitch 0° … 30° down from the authored 8°; distance refits to the framing sphere.
  Rationale: the upright bed must stay readable; a steeper pitch would foreshorten the mist wall.
