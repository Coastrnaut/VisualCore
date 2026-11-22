# Research: R02-G06-04

- **R1 Drag a star's start marker.** Decision: a drag of at least 16 points that starts on a star node at tick 0 sets
  that star's start phase to the loop index of the cell under the finger on release. Rationale: the design's "drag a
  star start marker"; picking the star at touch-down and the cell at release is unambiguous even where the node covers
  its own cell. Alternatives: tap a loop cell (ambiguous where loops share cells).
- **R2 Scrub the timeline.** Decision: a touch in the timeline band at the near edge maps its x to a tick; release sends
  a forward step, or a rewind and a step. Rationale: the kernel only replays forward from tick 0 (closed-form positions),
  so a rewind-and-step reaches any earlier tick exactly and ends in the plain replay's digest. Alternatives: a new kernel
  "seek" action (would change the kernel and its record format).
- **R3 Record a hold.** Decision: a long press (0.5 s, under 10 points, judged at release from event timestamps) on a
  star toggles its standard hold (start 1, length 10). Rationale: deterministic without timers; matches the panel's
  Add/Remove hold. Alternatives: drag on the timeline per star (needs a per-star timeline view, R02-G06-06 polish).
- **R4 Analytic picking.** Decision: the touch ray through the drawn camera against star spheres (radius 0.3·u at
  0.25·u), nearest hit, then the field plane y = 0 (loop cells, timeline band), with a 22-point fallback target.
  Rationale: R2-F22's analytic picking; deterministic and host-testable.
- **R5 Orbit bounds.** Decision: yaw ±40°, pitch 30° … 75° (authored 55°), distance refit to the bounding sphere.
  Rationale: R2-F22's constrained orbit avoids the vertical singularity and keeps the whole sky visible.
- **R6 The drag highlight.** Decision: the candidate cell gets a thin square pearl ring (inset 0.08·u, 0.06·u wide,
  lifted 0.01·u) drawn by the existing field program with the track material (silver) at shade 1; in the fallback a
  per-vertex-coloured ring. Rationale: no new GLSL.
