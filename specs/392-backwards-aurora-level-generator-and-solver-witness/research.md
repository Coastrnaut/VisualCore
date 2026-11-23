# Research: R02-G10-02

- **R1 Openings built from the target.** Decision: each candidate's opening is its own smooth target with k separated
  sections reversed. Rationale: every level is winnable by construction (reversing the same sections back) before the
  solver certifies its smallest count; the true wave is a gently curving aurora. Alternatives: random openings (often
  unreachable or trivially solved, long searches).
- **R2 A lower bound that a found solution meets.** Decision: β, the number of interior bends above L, falls by at most
  4 per reversal (only the seam bends take new values), so ⌈β / 4⌉ reversals are needed; separated sections whose 4
  seams all break L give β = 4k, and the k reversals back meet the bound. Rationale: a solution at the bound proves it
  smallest, as in features 372 and 382; this is the catalog's "endpoint continuity constraints" made exact.
  Alternatives: breadth-first search over all reversal sequences (496^k states; unbounded for k = 7).
- **R3 Iterative deepening over reversible sections.** Decision: depth-first search in the rules' move order with the
  bound starting at ⌈β / 4⌉ and the pruning depth + ⌈β / 4⌉ > bound; torn or failed states are leaves. Rationale: the
  catalog's "interval dynamic programming over reversible wave segments": every section is a candidate, the seam count
  prunes, the work is counted and bounded.
- **R4 Bands by length and precision, not speed.** Decision: higher bands have longer waves, more reversals, more
  checkpoints and a smaller breaking margin. Rationale: harder means more to read and a tighter fit, never faster
  reactions.
- **R5 Witness files as in feature 382.** Decision: sorted-key JSON with per-reversal sample digests, fingerprints, the
  lower-bound argument and the near miss; written only with the explicit switch.
