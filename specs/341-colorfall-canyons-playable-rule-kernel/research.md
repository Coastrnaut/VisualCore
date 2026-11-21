# Research: R02-G05-01

- **R1 Coarse-grid routing instead of free-surface fluid.** Decision: each cell passes up to the flow rate to its single
  steepest-descent neighbour (lowest strictly lower height; ties east, south, west, north). Rationale: the source asks
  for "coarse-grid deterministic water routing … no unstable free-surface CFD"; single-neighbour routing makes the flow
  graph a forest, reachability is exact and every move is an integer. Alternatives: splitting between all lower
  neighbours (rounding in every cell, harder to read), height-plus-depth pressure (not monotone, can oscillate).
- **R2 Synchronous update.** Decision: all moves of a tick are computed from the start-of-tick state. Rationale: the
  result does not depend on cell visit order, which keeps it identical on every device and easy to reproduce in a
  brute-force reference. Alternatives: in-place sweeps (order-dependent).
- **R3 Largest-remainder colour sharing.** Decision: an outflow r from volume V carries floor(r · m_c / V) of each colour,
  the leftover units going to the largest remainders, ties to the lower colour index. Rationale: whole units conserve
  each colour exactly (the source's "colour mass is conserved separately"); proportional sharing keeps the mix.
  Alternatives: oldest-first queues (more state), floating shares (drift).
- **R4 Failure before win, then time.** Decision: per tick contamination, overflow, win, time. Rationale: a basin that is
  contaminated or overflowing must never count as a win; time only ends a level that has not been decided.
- **R5 Full undo.** Decision: every carve, valve and step is undoable (snapshots), from playing, paused and failed; a won
  level is final. Rationale: nothing is hidden, so undo reveals nothing new; the source asks for pause, step and undo
  and an honest retry after failure.
