# Research: R02-G20-01

- **R1 Cycles, not seconds.** Decision: the kernel counts whole cycles of one run; the catalog's 0.016667 s timestep
  is the presentation clock of later features. Rationale: an exact clock; no floating point decides a rule.
- **R2 Integer humidity law.** Decision: humidity is a whole number of units per cell; diffusion, evaporation and
  release are integer sums with fixed divisors truncating toward zero. Rationale: the source's law ("humidity_{t+1} =
  humidity_t + D·laplacian·dt − evaporation + release") kept as written while every device gets bit-identical runs, so
  replays, fingerprints and certificates agree everywhere. Alternatives: `Double` with tolerance bands (a band edge
  decided by a last-bit difference would win on one device and fail on another).
- **R3 Flows, not a Laplacian per cell.** Decision: diffusion as one antisymmetric flow per adjacent pair, (hₐ − h_b)·D/64
  truncated toward zero. Rationale: the discrete Laplacian summed over pairs, with rounding that can never create or
  destroy water, so the ledger balances exactly ("humidity conservation with source/sink ledger"); D ≤ 12 keeps
  4·D/64 < 1, so the explicit step is stable and never drives a cell negative. Alternatives: the per-cell formula with
  rounding per cell (the total drifts by rounding, so the ledger would need an error term).
- **R4 Evaporation by vents and moonlight.** Decision: each cell's rate 0 … 200 (vents switch between two rates), scaled
  by (4 + L)/4096 for moonlight level L 0 … 3, never more than the cell holds. Rationale: "open or close canopy vents"
  and "shift moonlight intensity" become two exact controls on the sink; "bounded evapotranspiration" holds because a
  cell loses at most 200·7/4096 < 35 % a cycle.
- **R5 Growth by integral.** Decision: a pod's integral adds its cell's humidity after every cycle; at the threshold
  the pod releases its grown amount from the next cycle. Rationale: "growth triggered by time-integrated thresholds"
  made exact, and the one-cycle delay keeps the step synchronous.
- **R6 Stable at the end.** Decision: won when every colony is in band for each of the last K cycles. Rationale:
  "sustain preferred humidity band for T cycles" read as a stable network at the end of the run (a colony that drifts
  out at the last cycle is not sustained); the report still gives each colony's longest run.
- **R7 Failure order.** Decision: per cycle, `dried` (lowest sensitive colony below its floor) before `mold` (first
  cell above M in row-major order); after the run, `unstable`. Rationale: one named reason, colony or cell, and cycle.
- **R8 Run as the commitment.** Decision: arrangement actions cost actions and keep the level playing; `run` costs
  nothing and ends it; the predicted outcome is reported after every action. Rationale: as feature 481.
- **R9 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  pods, vents, moonlight, actions spent, stage, failure) and records with previous and next fingerprints, as feature
  481.
- **R10 Search space.** Decision: pods on free floor cells, up to six; vents open or closed; four moonlight levels.
  Rationale: R02-G20-02's "grid diffusion with bounded evapotranspiration and reachability checks" searches these
  arrangements over a small set of candidate cells.
