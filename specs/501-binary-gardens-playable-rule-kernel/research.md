# Research: R02-G21-01

- **R1 Ticks, not seconds.** Decision: the kernel counts whole ticks of one 48-tick cycle; the catalog's 0.008333 s
  timestep is the presentation clock of later features. Rationale: an exact clock; no floating point decides a rule.
  Alternatives: integrating with a real time step (the period would drift by rounding, and "a full cycle" would not be
  exact).
- **R2 Quantized analytic orbits.** Decision: 48 phase steps per cycle (7.5° each); a star's phase at tick t is
  (θ + ω·t) mod 48 with the shared ω 1 … 3, a world's (ψ + ν·t) mod 48 with ν −4 … 4 (non-negative modulo,
  ((x mod 48) + 48) mod 48). Rationale: every body moves a whole number of steps per tick, so tick 48 equals tick 0 for
  every body and the system's period is exactly 48 ticks; "orbit curves analytic" is kept as circles sampled at exact
  phases. Alternatives: Kepler ellipses or gravitational integration (the signature shader's "numerical gravitation in
  fixed steps" is presentation only; a judged state needs no integrator).
- **R3 The cosine table is data.** Decision: `BinaryGardensSky.cosine` is a literal array of 48 integers built from the
  quarter wave C[0 … 12] = 1024, 1015, 989, 946, 887, 812, 724, 623, 512, 392, 265, 134, 0 and the symmetry rules
  C[k] = −C[24 − k] (13 … 24), −C[k − 24] (25 … 36), C[48 − k] (37 … 47); `sine(k)` = C[(k + 36) mod 48]. A test checks
  each entry against the nearest integer to 1024·cos(7.5°·k) (the only place `Foundation.cos` appears, in a test) and
  against the symmetry rules. Rationale: "no run-time trigonometry in the rules"; one table on every device.
- **R4 Positions and distances.** Decision: integer coordinates at scale 2^20: a world at radius a, phase ψ is
  (a·C[ψ]·1024, a·S[ψ]·1024, 0); a star at ring radius ρ, phase θ and tilt τ is (ρ·C[θ]·1024, ρ·S[θ]·C[τ],
  ρ·S[θ]·S[τ]) (the orbit plane turned about the x axis by τ steps); squared distances at scale 2^40 as exact sums of
  squared differences. Rationale: the tilt multiplies the scale-1024 sine by a scale-1024 cosine, so both kinds of body
  share scale 2^20 without a division; the largest squared distance stays below 2^56.
- **R5 Milliflux with one truncating division per star.** Decision: star i gives world j
  ⌊1000·Lᵢ·2^40 / max(D, r_min²·2^40)⌋ milliflux; the world's flux at a tick is the sum of its two stars' shares, each
  truncated separately. Rationale: the source's law flux = Σ luminosityᵢ / max(rᵢ², r_min²) kept as written while
  every device gets bit-identical light; the clamp (r_min 1 … 8) removes every division by zero or near zero and caps a
  share at 1000·64 = 64 000. Alternatives: `Double` with tolerance bands (a band edge decided by a last-bit difference
  would win on one device and fail on another); one division over the sum (a rational sum would need a common
  denominator above 2^62).
- **R6 Five bands per tick.** Decision: lethal low (F < λ_lo), dim (λ_lo ≤ F < c_lo), comfortable (c_lo ≤ F ≤ c_hi),
  bright (c_hi < F ≤ λ_hi), lethal high (F > λ_hi), with 0 ≤ λ_lo < c_lo ≤ c_hi < λ_hi ≤ 200 000. Rationale: a lethal
  bound itself is not lethal and a comfortable bound is comfortable (spec edge cases); the classification is a total
  function of F.
- **R7 The lethal walk across the boundary.** Decision: walk ticks t = 1 … 48 + E; tick t > 48 has the same positions
  and flux as tick t − 48. At each tick, worlds in ascending order: a lethal tick (low or high) extends the world's run,
  any other tick resets it to 0; the first (tick, world) at which a run reaches E + 1 fails `frozen` when that tick is
  lethal low and `scorched` when lethal high, with the world and the walk tick t (1 … 60; the words add "tick 2 of the
  next cycle" for t > 48). Rationale: a run that starts late in the cycle and continues into the next is counted whole,
  and no run longer than E can be missed because any such run reaches E + 1 within at most E ticks after tick 48.
  Mixed runs (lethal low then lethal high without a non-lethal tick between) are one run, named by the tick that
  exceeds the tolerance, as the clarification states.
- **R8 Cyclic comfortable window.** Decision: the longest run of consecutive comfortable ticks over ticks 1 … 48 read
  cyclically (tick 48 followed by tick 1), with its start tick (the smallest start among equal longest runs; tick 1
  when all 48 are comfortable, length 48). Computed by scanning the 48 ticks twice and capping at 48. Rationale: "a
  stable illumination window across a full cycle"; a window exactly W long holds.
- **R9 Judge order.** Decision: (1) the lethal walk (frozen / scorched); (2) only without a lethal failure, worlds in
  ascending order, and for each world first `unstable` (window < W, with world, window and required) then `wilted`
  (I < B_lo) or `bleached` (I > B_hi) (with world, integral and band); the first failing world names the failure;
  (3) otherwise won. Rationale: FR-R02G2101-005 and the clarification both name "the lowest-numbered such world"; within
  one world the window is checked before the bloom band, so the global order is frozen/scorched → unstable →
  wilted/bleached for any one world. Alternative rejected: all worlds' windows before any world's bloom (it would name a
  higher-numbered unstable world before a lower-numbered wilted one, against "lowest-numbered").
- **R10 Separation as a level and action invariant.** Decision: the stars' squared separation at every tick 0 … 47
  (the same 48 configurations as ticks 1 … 48) must be ≥ σ²·2^40 (σ 0 … 16; 0 always holds); the level's start must
  hold it, and every action is refused `r02-g21.action` when the new arrangement breaks it; exactly σ is allowed.
  Rationale: "the stars' minimum separation" decided exactly; the report gives the minimum squared separation and its
  tick.
- **R11 Run as the commitment.** Decision: arrangement actions cost one action each and keep the level playing; `run`
  costs nothing, is allowed with the budget spent, and ends the level won or failed; the predicted outcome is reported
  after every action; undo from failed returns to playing with the arrangement before the run (recorded); a won level
  is final. Rationale: as features 481 and 491.
- **R12 Where the tests run.** Decision: CI: `BinaryGardens` joins half b of `round02-host-tests` (G11 … G20 and now
  G21), keeping the split by game: half a stays G01 … G10 and every later game of round two joins half b until a run
  nears the limit, when a third group is added. Local: chunk 2 (`MoonlitMechanism|AcousticConstellator|HarmonicBridges`,
  48 s at R02-G20-10) gains `BinaryGardens`, the lightest of the five chunks (1: 57 s, 3c: 138 s, 3e: 211 s, 3f: 147 s);
  feature 491 placed Mushroom Weather in 3f, which already has five games. Rationale: the new tests run in exactly one
  CI half and one local chunk; the chunks stay balanced and far below 540 s. Alternatives: 3f (heaviest by game count);
  a sixth chunk (more runs per gate for seconds of tests).
- **R13 Fingerprints as the signed snapshot.** Decision: the level fingerprint is SHA-256 (`StableHash.sha256Hex`) of a
  canonical text of every level field in a fixed order; the play fingerprint is SHA-256 of schema, level fingerprint,
  arrangement, actions spent, stage and failure; every record carries the previous and next fingerprints, as feature
  491. The stored form is sorted-key JSON schema 1; decode re-runs the initializer's checks and passes its `.level`
  refusal through (feature 491's convergence finding T-R02G2001-013), and reports a fingerprint mismatch or broken JSON
  as `.malformed`.
- **R14 Search space for R02-G21-02.** Decision: the puzzle position is the arrangement (both stars' ring, phase and
  luminosity, and the tilt) plus actions spent; moves in a fixed order: for star 1 then star 2, rings ascending, then
  phases 0 … 47, then luminosities ascending (each skipping the current value, locked controls and separation
  breakers), then tilts 0 … T_max (skipping the current); at most 120 moves, within `FairnessBudget.maxBranching`
  (1 024). Rationale: "bounded coupled-orbit parameter sweep with sampling of received flux" sweeps exactly these
  arrangements; the goal test is the kernel's predicted win.
- **R15 Budget from the start at 1 … 24.** Decision: the action budget range is 1 … 24. Rationale: Mushroom Weather's
  feature 492 had to widen 1 … 12 to 1 … 24 for the manifest; the R02-G21 manifest needs 8 … 19.
