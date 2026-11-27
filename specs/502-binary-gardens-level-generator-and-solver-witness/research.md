# Research: R02-G21-02

Facts checked read-only on 2026-11-27 against the committed kernel (`Packages/ExperiencesRound02/BinaryGardens/Core`,
commits of R02-G21-01 up to T-006): `BinaryGardensLevel` (ranges, refusal order: range checks, then "nothing
adjustable", then encoding, then "separation", then "already won"; `probe(...)` skips "already won"),
`BinaryGardensSky.changed(_:_:by:)` (refusal order star, range, locked, unchanged, separation; the play and the puzzle
contract both call it), `BinaryGardensSky.isWellFormed`, `keepsSeparation`, `report`, `BinaryGardensPuzzle.moves(in:)`
(star 1 then star 2: rings ascending, phases 0 … 47, luminosities ascending; then tilts 0 … T_max) and
`BinaryGardensFailure` (Codable, with `code` and `world`). The model is feature 492's code
(`MushroomWeatherManifest`, `Solver`, `Difficulty`, `Generator`, `Witness` and their tests).

- **R1 A phase step makes the proof whole.** Decision: catalog levels declare a phase step, 8 in bands 1 … 2 and 6 in
  bands 3 … 5 (6 and 8 phase values instead of 48); phase actions off the grid are refused. Rationale: with 48 phases a
  phase control has 47 other values, and a band-5 space within four actions grows past 10^5 arrangements, far beyond a
  test budget; with the grid the largest space is 4,048 (R10), and the minimality proof covers every move the player
  has, because the off-grid moves do not exist for that level. "Quantize … to legal values" in every manifest row reads
  naturally as this grid. g = 1 keeps feature 501 unchanged (stored form, fingerprint, moves). Alternatives: proving
  minimality only over grid phases while the player may set any phase (rejected: not a proof of what the player can
  do); coarser rings or tilts (rejected: already at most 5 and 4 values).
- **R2 Where the grid is enforced.** Decision: `BinaryGardensLevel.init` refuses "phase step" (not a divisor of 48 up to
  24) and then "phase off grid" (a starting phase not a multiple of g), after "nothing adjustable" and before encoding,
  so both precede "separation" and "already won" as clarification Q1 requires; `BinaryGardensSky.changed` refuses
  `.action("off the phase grid")` right after "phase out of range" and before "locked"; `isWellFormed` also requires
  phases on the grid; `BinaryGardensPuzzle.candidates()` lists phases 0, g, 2g, …. Rationale: one check serves the play
  and the puzzle contract, so "a move is legal exactly when the play accepts it" (feature 501) still holds; an off-grid
  step is a range error of that level, so it sits with the range checks. Alternative: refusing in the play only
  (rejected: the puzzle contract would list moves the play refuses).
- **R3 Breadth-first sweep over legal moves.** Decision: the solver is a breadth-first search by the number of actions:
  depth 0 is the start; depth d + 1 expands the arrangements of depth d in ascending order of their loss (ties keep
  discovery order), each with `BinaryGardensPuzzle(level:).moves(in:)` in its fixed order, skipping arrangements
  already reached at any depth (including earlier in the same depth) and judging each new arrangement on discovery.
  Rationale: unlike Mushroom Weather (feature 492, R2), the number of controls changed is not always the action
  distance — a direct order can break the separation σ and force a detour — so only a search over legal moves gives the
  exact depth; reusing the puzzle contract's moves makes the solver's legality the kernel's by construction. Expanding
  in loss order changes only how soon the winning depth meets its first win (every smaller depth is judged in full),
  so the depth found is minimal. Alternative: enumerating changed-control subsets as 492 did (rejected: inexact under
  σ > 0, which bands 3 … 5 use).
- **R4 Constructive generator; ranges measured first.** Decision: draw the controls, the sky, the winning arrangement
  and the worlds; set every world's bounds from its winning run; then draw the p changed controls and their starting
  values; let the solver confirm that the minimal plan has exactly p actions. Rationale: building from a winning run
  guarantees a win exists and that its run is inside every band; the lesson of R02-G10-02 and feature 492 (simulate a
  generator's filters before writing them down) applies. **Measurement (first implementation step, T-R02G2102-003/004,
  before any test depends on the profiles):** run the real generator and solver on the committed kernel over the 100
  manifest entries in a debug host build and record here: the largest accepted candidate index per band, the number of
  entries needing more than candidate 0, the work per level (largest per band) and for the whole catalog, the witness
  lengths by band (must equal p: 1, 2, 3, 3, 4), the slowest level and the slowest group of five, and the catalog's
  total time. The plan stage cannot run it: test chunks occupy this machine and agents never run builds, so it is the
  first step of implementation, as clarification Q1's "prototype" — its numbers land here and in plan.md's Technical
  Context. **Adjustment ladder** (only if an entry reaches `generation(n)`, a band's witness lengths are not its p, or
  a group exceeds 6 s): (1) when candidates are skipped as "reducible", "already won" or with a plan shorter than p
  (bands too loose, so fewer changes win), narrow the comfort margin m, then the window slack s, then the bloom margin
  b; (2) when the plan is longer than p (separation detours), lower the band's σ range; (3) when c_lo = 0 skips
  dominate (a far world at luminosity 4 receives only a few milliflux, at most 1000 · 32 / 3² ≈ 3,555 for the nearest
  and brightest), raise the trim k; (4) when a band is slow, lower its world count. Never the
  plan lengths p, the phase steps or the budgets. Each changed value is written back into spec
  clarification Q1, data-model.md and this entry in the same commit. Measured values: recorded here by T-R02G2102-003.
- **R5 Reducible pre-filter.** Decision: skip a candidate when the winning arrangement with any one changed control put
  back to its starting value still wins. Rationale: such a candidate would fail the plan-length check after a full
  search; at most p ≤ 4 reports decide it. It is also the novelty invariant's core (every changed control matters).
- **R6 Witness order.** Decision: the plan is the winning arrangement's parent chain from the start (the moves the
  sweep took), then `run`. Rationale: every prefix is an arrangement the sweep reached legally (the separation holds
  after every action), so the plan replays through the play without refusal; the order is deterministic.
- **R7 Neighbour rule.** Decision: skip a candidate whose ring radii and worlds (every field of every world) equal the
  previous level's. Rationale: the manifest asks for a genuinely different puzzle from adjacent seeds; the level id
  differs anyway, so fingerprints always differ and the rule must compare content.
- **R8 State digest.** Decision: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 text
  `rings=a,b;phases=a,b;luminosities=a,b;tilt=t;spent=s` (indices, as stored), one digest after every action including
  `run`. Rationale: compact; detects any change in the rules or the replay; the format follows 492's canonical text.
- **R9 Counterexample.** Decision: the depth p − 1, the number of arrangements the solver judged at exactly that depth
  (none winning), the nearest miss (the smallest loss among every arrangement judged at depths 0 … p − 1, the first in
  judging order among equals), its arrangement and its first failure (`BinaryGardensFailure`: frozen or scorched with
  world and walk tick, unstable with world, window and requirement, wilted or bleached with world, integral and band).
  Rationale: a concrete, re-checkable proof of minimality with an explanation of the closest wrong answer, as the
  manifest's "negative counterexample" asks.
- **R10 Work bound 5,000 from arithmetic.** Decision: count arrangements judged, bound at 5,000. Rationale: the largest
  space up to a plan depth is the sum of elementary symmetric products of the adjustable controls' other-value counts
  (an arrangement reachable in d actions differs from the start in at most d controls): band 1 {5, 5} within 1 action
  = 11; band 2 {5, 5, 3} within 2 = 69; band 3 {7, 7, 3, 3} within 3 = 583; band 4 {7, 7, 4, 4, 3} within 3 = 1,416;
  band 5 {7, 7, 4, 4, 3} within 4 = 1 + 25 + 243 + 1,147 + 2,632 = 4,048 (recomputed 2026-11-27). The bound is a guard
  above all of them; over it the candidate is skipped (counted, never timed).
- **R11 Groups of five; CI time.** Decision: certification tests in 20 groups of 5 levels; generated levels cached per
  process. Rationale: a band-5 candidate judges at most about 4,000 reports with their move lists (each report about
  1,000 integer steps, each move list up to 38 separation checks of 48 ticks), a fraction of a second in a debug build;
  five levels with a few skipped candidates fit 10 s, confirmed by the R4 measurement. On CI the half-b job runs about
  three times slower; the catalog's added time is checked with `gh run list` after the push, and the split of half b is
  revisited only if a run nears its 60-minute limit.
- **R12 Bounds from the winning run.** Decision: with the band's trim k and margins: c_lo = ⌊F₍ₖ₎·(1000 − m)/1000⌋,
  c_hi = ⌈F₍₄₉₋ₖ₎·(1000 + m)/1000⌉, λ_lo = min(c_lo − 1, ⌊F₍₁₎·(1000 − ℓ)/1000⌋), λ_hi = max(c_hi + 1,
  ⌈F₍₄₈₎·(1000 + ℓ)/1000⌉), W = max(1, w* − s) with w* the winning run's longest cyclic comfortable window under
  (c_lo, c_hi), B_lo = ⌊I*·(1000 − b)/1000⌋, B_hi = ⌈I*·(1000 + b)/1000⌉; ceilings as (x + 999)/1000 on non-negative
  integers. Rationale: exact; the winning run has no lethal tick, keeps every window and bloom band. Note: the kernel
  caps a world's flux at 128 000 milliflux per tick, so λ_hi ≤ 166 400 and B_hi ≤ 7 065 600: the "λ_hi above 200 000"
  skip of clarification Q1 cannot fire and is kept as a guard and tested as a bound (as feature 491 tested its
  evaporation cap); c_lo = 0 can fire (a far, dim world).
- **R13 Content and novelty invariants.** Decision: `testBinaryGardensContentBoundary` (every catalog level has a
  witness that replays to a win within its budget and whose difficulty work and arrangements equal the solver's run;
  neighbouring input, seed 2_507: one seeded edit per sampled witness — an action value, a digest character or a
  difficulty count — is refused `r02-g21.witness`) and `testBinaryGardensNoveltyBoundary` (every witness consists only
  of ring, phase, luminosity and tilt actions then `run`; putting back any one changed control of the winning
  arrangement makes the run fail; neighbouring input, seed 2_507: dropping one seeded action of a sampled witness
  never wins). Rationale: the mechanic is checked, not its name (spec FR-R02G2102-008).
- **R14 Independent minimality check.** Decision: on the two levels with the smallest move space in each band (ties by
  level number), enumerate every action sequence of length 0 … p − 1 through `BinaryGardensPuzzle` moves with no
  visited set and no loss order; judge every reached arrangement with `BinaryGardensSky.report`; none wins; the number
  of arrangements first reached at each length equals the solver's `arrangementsByDepth`; one sequence of length p
  wins. Rationale: shares only the kernel with the solver. Size: at most 25 moves per state, so at most
  1 + 25 + 625 + 15,625 states for band 5, a few seconds at most in a debug build.
- **R15 Drawing details the spec leaves open.** Decision: a range is drawn with `SeededRandom.int(_:)`; a partial
  shuffle takes n of m items by n steps of Fisher–Yates with `index(below:)`; a world speed draws its magnitude 1 … 3
  then its sign (`index(below: 2)`, 1 = negative); the emphasised control's star is `int(0...1)`; T_max, the ring,
  luminosity and world counts are drawn from the band's range where the profile gives one (band 2's T_max 2 … 3).
  Rationale: deterministic and recorded, so the drawing-order test of agent C can pin it.
