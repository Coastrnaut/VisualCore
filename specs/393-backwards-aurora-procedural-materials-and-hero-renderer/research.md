# Research: R02-G10-03

- **R1 World mapping.** Decision: the timeline stands upright as the plane z = 0, x = −1 + (k + 0.5)·2/N for sample k
  and y = 0.6·s / 64, so every wave (12 … 32 samples, heights −64 … 64) fills the same box (x −1 … 1, y −0.6 … 0.6).
  Rationale: one camera fits every level; each drawn vertex names a kernel sample. Alternatives: a spiral or horizontal
  ribbon in depth (rejected: samples and checkpoints become hard to read on a phone).
- **R2 The ribbon is the kernel's samples.** Decision: the ribbon is the polyline through the exact sample points,
  each segment tessellated into straight steps for shading only; no curve is smoothed or computed on the GPU.
  Rationale: renderer purity (US2) and the frame checks name exact samples. Alternatives: spline ribbons (rejected: the
  picture could show bends the rules do not have).
- **R3 Direction-coded pulses.** Decision: beads travel left to right along the ribbon and right to left inside the
  chosen section, the way a reversal folds it; they move with presentation time only. Rationale: the design's
  "direction-coded pulses" and "folding backward through time" without any rule effect.
- **R4 Shape is the non-colour twin.** Decision: checkpoints are rings filled when matched, sharp bends carry crosses,
  a tear a larger cross, the section a dashed band, the gauge a row of bars. Rationale: R2-F10's rule.
- **R5 Camera.** Decision: a fixed authored view from +z fitted to the box x −1 … 1, y −0.95 … 0.75 for aspects 0.4 …
  2.5 with a 5 % margin. Rationale: everything readable on a phone; gestures in R02-G10-04.
- **R6 Reuse of R02-G09-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Nocturne Garden's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; the adapter certifies each level directly from its recorded candidate.
