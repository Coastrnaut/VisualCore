# Research: R02-G07-01

- **R1 Discrete shells instead of continuous angles.** Decision: every shell has N equal sectors and an integer offset;
  a pocket's own sector is (absolute − offset) mod N (clarification Q2). Rationale: the source's "shell rings rotate in
  fixed increments" and "discretized shell angles" are exactly these integers; every device decides the same and the
  solver of R02-G07-02 can search them breadth-first. Alternatives: floating-point angles with tolerances (device drift).
- **R2 One deterministic transition per advance.** Decision: outward through an aligned aperture, else one sector
  clockwise unless a radial wall blocks, else refused. Rationale: "deterministic pocket transitions" with a single,
  explainable rule; refusing a blocked roll keeps every accepted advance a real move. Alternatives: rolling until stopped
  (several pockets per tap hide the route), letting the player choose a direction (two moves for one tap).
- **R3 Connectivity from the offsets alone.** Decision: nothing is cached; each advance reads the current offsets.
  Rationale: "connectivity graph is recomputed at angle changes" without state that could go stale under undo.
- **R4 Exit, then wedge, then budget.** Decision: judged after each accepted move in that order; nothing before the
  first move. Rationale: an exit on the last move wins; a level is never won before the player acts.
- **R5 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  offsets, pearl, moves, stage, failure) and records with previous and next fingerprints, as feature 351. Rationale: the
  source's tamper-evident replay without key material.
