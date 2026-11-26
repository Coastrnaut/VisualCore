# Research: R02-G19-01

- **R1 Ticks, not seconds.** Decision: the kernel counts whole ticks of one swim; the catalog's 0.008333 s timestep is
  the presentation clock of later features. Rationale: an exact clock; no floating point decides a rule.
- **R2 Integer swarm law.** Decision: positions and velocities are `Int64` dish units; separation, alignment, cohesion
  and the wells' curl are integer sums with fixed divisors truncating toward zero; acceleration and velocity are
  clamped per axis; semi-implicit Euler. Rationale: the source's law ("bounded separation/alignment/cohesion
  accelerations plus magnetic curl field; stable fixed-step integration") kept as written while every device gets
  bit-identical swims, so replays, fingerprints and certificates agree everywhere. Alternatives: `Double` with
  tolerance bands (the source allows it, but a swarm is chaotic: a last-bit difference grows until a level wins on one
  device and fails on another); per-axis clamps against a Euclidean speed limit (a square root, and its rounding, for
  no player-visible gain).
- **R3 Synchronous step.** Decision: all accelerations come from the tick's state before any swimmer moves. Rationale:
  the result cannot depend on swimmer order; the source's "avoid nondeterministic iteration" holds by construction.
- **R4 Softened curl.** Decision: the curl magnitude is proportional to distance over (distance² + 256²), turning
  around the well's cell centre. Rationale: bounded near the well (no singularity), fading with distance, so wells act
  locally like the source's "magnetic wells"; a pure curl adds no attraction, so the swarm rules keep it together.
- **R5 Trail density by cell.** Decision: a cell's density counts the ticks swimmers spend in it; lit at a level
  threshold. Rationale: "trailing density" made exact; the drawn ribbons of R02-G19-03 follow the same positions.
- **R6 Coverage and one group.** Decision: coverage in tenths of a percent of the stencil, rounded down; connectedness
  as exactly one four-neighbour group of lit stencil cells. Rationale: "occupies target stencil with sufficient
  connectedness" made exact and explainable ("34 of 40 cells, one pattern").
- **R7 Coherence by links.** Decision: swimmers linked within κ; coherence is the largest linked group, checked after
  every tick. Rationale: "destroys required coherence" becomes a named tick and group size.
- **R8 Play as the commitment.** Decision: placements cost actions and keep the level playing; `play` costs nothing
  and ends it; the predicted outcome is reported after every action. Rationale: as feature 471.
- **R9 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  wells, actions spent, stage, failure) and records with previous and next fingerprints, as feature 471.
- **R10 Search space.** Decision: wells on inside cells, strengths 1 … 4, two senses, at most three wells. Rationale:
  R02-G19-02's "low-dimensional field strength search" searches strengths and senses over a few candidate cells. Found while
  implementing (2026-11-26): the full move list of `MicroscopicAuroraPuzzle` reaches about 9,100 placements at radius
  11, far above R02-F23's `FairnessBudget.maxBranching` of 1,024, so R02-G19-02's certification uses a narrowed move
  set (the level's candidate cells), as this decision intends.
