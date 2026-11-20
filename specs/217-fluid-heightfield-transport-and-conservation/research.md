# Research: R02-F17

- **R1 Integer quanta.** Decision: `Int64` quanta, 65,536 per height unit, 0 … 2⁴⁰ per cell. Rationale: every transfer is
  an integer subtraction and addition of the same value, so totals are exact on every device; 2⁴⁰ · 262,144 cells stays
  below 2⁶³. Alternatives: `Double` amounts (totals drift by rounding), `Float` on the GPU (worse).
- **R2 Virtual pipes.** Decision: the pipe model of O'Brien and Hodgins (1995), as used for erosion by Mei, Decaudin and
  Hu (2007): fluxes accelerate with the surface drop, are kept between steps (momentum), damped, clamped at zero and
  scaled so a cell never sends more than it holds. Rationale: explicit, local, stable under a time-step bound, and the
  scaling makes non-negativity structural. Alternatives: diffusion (no momentum, unnatural), full shallow-water
  equations (needs implicit solves).
- **R3 Two-phase transfer.** Decision: all cells compute their sends from start-of-sub-step amounts, then all apply.
  Rationale: the result does not depend on visiting order, so it is deterministic and symmetric.
- **R4 Proportional carriage.** Decision: dye and sediment leave with floor(amount · sent / water) per direction using
  full-width multiplication (`multipliedFullWidth`, `dividingFullWidth`). Rationale: exact, cannot overflow, and a cell
  that sends all its water sends all its dye.
- **R5 Stability bound.** Decision: h = min(maxSubstep, 0.25 · l / √(g · depth_max)), at most 64 sub-steps per frame step.
  Rationale: the pipe model's gravity-wave speed is √(g · d); a quarter of the cell-crossing time keeps it stable.
- **R6 Erosion.** Decision: capacity C = K_c · |v| · max(slope, 0.01) · depth, dissolve and settle at rates K_s, K_d
  (Mei et al. 2007), turned into whole quanta and limited by what is present. Rationale: standard, local and exactly
  conserving when expressed as an in-cell exchange.
- **R7 Drawing.** Decision: `fieldGrid()` returns a `FieldGrid` (terrain, water depth, sediment, then dye, in height
  units). Rationale: the existing passes upload and draw `FieldGrid`s; no rendering change is needed.
