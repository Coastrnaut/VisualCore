# Research: A24-P01 (feature 173)

- **R1 Percentile definition.** Decision: nearest rank, ⌈p·n/100⌉ in integers. Rationale: every reported value is a
  real sample, ties are stable, and fixtures can be computed by hand. Alternatives: linear interpolation (values no
  frame had; rejected), `PacingMeter`'s 0.25 ms bins (rounds results; rejected at A24-P00).
- **R2 Minimum counts.** Decision: p95 needs 20 samples and p99 100. Rationale: with fewer, the percentile is the
  maximum and claims more than it knows. Alternative: always report (rejected: misleading).
- **R3 Intervals from frame times.** Decision: the interval is the difference of consecutive frame times, absent for
  the first frame of a run; the clamped `FrameInfo.delta` is never used (A24-P00 clarification Q3).
- **R4 Stored summary.** Decision: the file stores the summary and the reader recomputes it from the samples; a
  mismatch is `damaged`. Rationale: a hand-edited summary cannot pass as a measurement.
- **R5 Caps.** Decision: the clarification's table, a 210 s run maximum and 20,000 samples. Rationale: bounded stress
  (constitution A24, manual risk 3); the numbers are bounds, not targets.
