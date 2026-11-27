# Feature Specification: R02-G21-02 — Binary Gardens: level generator and solver witness

**Feature Branch**: `502-binary-gardens-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-02 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2102-###,
SC-R02G2102-###, T-R02G2102-###

**Input**: User description: the archived R02-G21-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Binary Gardens, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/502-binary-gardens-level-generator-and-solver-witness`; FR-R02G2102-###,
  SC-R02G2102-###, T-R02G2102-###.
- **Packaging (ADR-0009):** experience R02-G21 (`r02-g21.binary-gardens`, free) in the one app; this feature extends
  the pure Binary Gardens Core of feature 501 (module `Packages/ExperiencesRound02/BinaryGardens`). No app target,
  bundle identifier, scheme or store listing.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G21`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19 by band, control emphases `adjust orbit`, `phase twin
  stars`, `set luminosity`, `watch world` and `commit light window`, 20 each). The prompt's "content count 81" (the
  catalog's "81 solver-certified stages" and the 81-row production table of the archived design's section 5) is a
  milestone figure, as for the earlier round-two games (features 491 and 501): the archived 100-stage manifest states
  that IDs 001 … 080 extend the original milestone and 081 … 100 are the parity expansion, so 81 is a count reached on
  the way and not a different catalog.
- **Kernel extension (additive):** every manifest budget (8 … 19) lies inside feature 501's budget range 1 … 24, so the
  budget needs no change. A level may declare a phase step, the grid on which star phases lie, so the solver searches,
  and proves minimality over, a bounded move space ("quantize … to legal values" in every manifest row). A level without
  a phase step keeps feature 501's behaviour, stored form and fingerprint.
- **Model:** feature 492 (Mushroom Weather's content pipeline) and feature 482 (Microscopic Aurora's) for manifest,
  generator, solver, witness files, digest and progression, adapted to the light rules of feature 501: a move sets a
  star's ring, phase or luminosity or the orbit tilt, and the run ("commit light window") ends the level.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following features
492 and 482 where the games agree. Facts checked (read-only, 2026-11-27): feature 501's specification and data model
(`BinaryGardensLevel` with 2 … 8 ring radii 1 … 40, star speed 1 … 3, 1 … 4 luminosity levels 1 … 64, two stars with
three adjustable flags each, tilt 0 … T_max with T_max 0 … 6, separation σ 0 … 16, clamp radius 1 … 8, 1 … 5 worlds,
tolerance 0 … 12, budget 1 … 24, a starting arrangement that must keep the separation and must not win; the 48-step
integer geometry; flux in milliflux, truncated per star; the judge order lethal → window → bloom, worlds ascending;
`BinaryGardensPuzzle` whose moves are the legal ring, phase, luminosity and tilt actions while actions are left); the module is committed (R02-G21-01 up to T-006; research.md lists what was read), and the search sizes below are
arithmetic bounds, not measurements; R02-F24's `PuzzleCatalog.digest(id:identities:)` and the
standard `ProgressionRule` (drop at most 1, jump at most 3); `SeedDerivation.derive(_:index:)` and `SeededRandom`; the
canonical manifest's 100 entries (bands 1 … 5 × 20, budgets as above, five control emphases, 20 each; each row also
names one of five required concepts — `bounded inverse-square flux`, `circumbinary orbit phase`, `planet survival
integral`, `time window coverage`, `minimum separation` — 20 each). The first implementation task (T-R02G2102-003, before any test depends on the profiles) runs the real
generator and solver on the committed kernel over the real 100 entries and records in research.md R4 the largest
candidate index per band, the work per level and for the catalog, the witness lengths by band and the slowest level
and group of five; a profile value changed there is written back into this section, research.md R4, data-model.md and plan.md's Technical Context in
the same commit, never left divergent.

- Q: How does the kernel change, and how is a level built from its manifest entry? → A: the kernel gains an optional
  phase step g ∈ {1, 2, 3, 4, 6, 8, 12, 16, 24} (the divisors of 48 up to 24); with g > 1 every starting star phase must
  be a multiple of g, and a phase action to a step that is not a multiple of g is refused `r02-g21.action` ("off the
  phase grid") by the play and is not a move of the puzzle contract; g = 1 is the default and is omitted from the stored
  form, so a level without it encodes, fingerprints and plays exactly as in feature 501. The level refuses, after
  feature 501's range checks and before its separation and already-wins checks, "phase step" (not one of the divisors)
  and "phase off grid" (a starting phase not a multiple of g). The 100 entries are a table in `BinaryGardensManifest`
  with their provenance. Candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index:
  c))`, in this order: the adjustable controls (the band's count, out of the seven controls star 1 ring, phase,
  luminosity, star 2 ring, phase, luminosity and tilt; the emphasised control first when the emphasis names one —
  `adjust orbit` a ring, `phase twin stars` a phase, `set luminosity` a luminosity, each on a star drawn 1 … 2 — the rest
  by a partial shuffle); the star speed ω (1 … band maximum); the ring count and the ring radii (distinct, drawn in
  2 … 12 for bands 1 … 2 and 2 … 16 for bands 3 … 5, sorted); the luminosity level count and levels (distinct in
  4 … 32, sorted); the phase step (the band's); T_max (the band's when the tilt is adjustable, else 0); σ (the band's
  range); the clamp radius (2 … 4); the winning arrangement (each star's ring, a phase that is a multiple of g and a
  luminosity, and a tilt 0 … T_max; redrawn up to 16 times until it keeps the separation); the worlds (the band's count;
  each a radius from the largest ring radius + 3 to min(60, largest + 20), a phase 0 … 47 and a speed drawn from
  ±1 … ±3); the margins of each world (comfort margin m, lethal margin ℓ, bloom margin b and window slack s, the band's
  ranges); the lethal tolerance E (the band's range); the changed controls (the band's plan length p of the adjustable
  controls, by a partial shuffle) and, for each, a starting value drawn uniformly among its other legal values (redrawn
  up to 16 times until the start keeps the separation); locked controls start at their winning values. Each world's
  bounds come from its winning run (flux F at ticks 1 … 48, sorted F₍₁₎ ≤ … ≤ F₍₄₈₎, integral I*): with the band's trim
  k, c_lo = ⌊F₍ₖ₎·(1000 − m)/1000⌋ and c_hi = ⌈F₍₄₉₋ₖ₎·(1000 + m)/1000⌉; λ_lo = min(c_lo − 1, ⌊F₍₁₎·(1000 − ℓ)/1000⌋)
  and λ_hi = max(c_hi + 1, ⌈F₍₄₈₎·(1000 + ℓ)/1000⌉); W = max(1, w* − s) for the winning longest cyclic comfortable
  window w*; B_lo = ⌊I*·(1000 − b)/1000⌋ and B_hi = ⌈I*·(1000 + b)/1000⌉, all in exact integer arithmetic, so the
  winning run has no lethal tick and keeps every window and bloom band. Band profiles (adjustable controls, rings,
  luminosity levels, phase step, T_max, worlds, σ, ω maximum, trim k, m ‰, ℓ ‰, b ‰, s, E, plan p): band 1 (2, 3, 2, 8,
  2, 1, 0, 1, 1, 60 … 90, 300, 150, 4 … 8, 6 … 8, 1), band 2 (3, 3 … 4, 2 … 3, 8, 2 … 3, 1 … 2, 0, 2, 4, 40 … 70, 250, 100,
  3 … 6, 4 … 6, 2), band 3 (4, 4, 3, 6, 3, 2, 2 … 4, 2, 6, 30 … 50, 200, 80, 2 … 4, 3 … 5, 3), band 4 (5, 4 … 5, 3, 6, 3,
  2 … 3, 2 … 5, 3, 8, 20 … 40, 150, 60, 1 … 3, 2 … 4, 3), band 5 (5, 5, 3 … 4, 6, 3, 3, 3 … 6, 3, 10, 10 … 30, 100, 40,
  0 … 2, 1 … 3, 4). A luminosity control is never drawn adjustable while the level has one luminosity level (every band
  has at least two). Budget = the manifest's; ids `binary-gardens-NNN`; tutorial on levels 1 … 3; difficulty = band.
  A candidate is skipped when the winning arrangement or the start cannot keep the separation within its tries, a world's c_lo is 0 (the kernel needs 0 ≤ λ_lo < c_lo) or its λ_hi exceeds the kernel's 200 000 (a guard that
cannot fire: a world receives at most 2 · 64 000 milliflux per tick, so λ_hi ≤ 166 400; tested as a bound), the level rules refuse it (including a start that already wins), the
  winning arrangement with any one changed control put back to its starting value still wins ("reducible"), its ring
  radii and worlds equal the previous level's (FR-R02G2102-007), the solver's minimal plan is not p, or the plan does
  not win through the play; at most 64 candidates, then `generation(n)`. Impact: FR-R02G2102-001, 007, 009;
  SC-R02G2102-001, 003, 004.
- Q: How does the solver find a minimal plan, and what proves nothing shorter wins? → A: the source's "bounded
  coupled-orbit parameter sweep with sampling of received flux" is a breadth-first sweep over arrangements (rings,
  phases, luminosities, tilt) by the number of actions from the start, each judged by the kernel's exact report, which
  samples every world's received flux at each of the 48 ticks. An action sets a control directly, so a later setting of
  the same control overrides an earlier one, and an arrangement reachable in d actions differs from the start in at
  most d controls; an action that breaks the separation is refused, so the sweep follows only legal moves and its depth
  is the exact action distance. Depth 0 is the start. Depth d + 1 takes the arrangements of depth d in ascending order
  of their loss (ties keep their discovery order) and, from each, the moves in the fixed control order (star 1 ring,
  phase, luminosity, star 2 ring, phase, luminosity, tilt), values ascending, skipping arrangements already reached at
  any depth (reachability, never pruning by outcome) and moves the kernel refuses; each new arrangement is judged on
  discovery. Loss = Σ over worlds of [Σ over ticks 1 … 48 of max(0, c_lo − F, F − c_hi) + max(0, B_lo − I, I − B_hi) +
  1000·max(0, W − window)], in milliflux. The first winning arrangement ends the search; the plan is its path of moves
  from the start (its parent chain), then `run`, replayed through the kernel's play, whose report must agree. Work =
  arrangements judged, counted and bounded at 5,000 per candidate, above the largest search space up to a plan depth
  (band 5: five adjustable controls with at most 7, 7, 4, 4 and 3 other values give 1 + 25 + 243 + 1,147 + 2,632 = 4,048
  arrangements within 4 actions; band 4 within 3: 1,416; band 3: 583; band 2: 69; band 1: 11), as a guard; over the bound
  the candidate is skipped (counted work, never timed). Search depth: at most the band's plan length p (1, 2, 3, 3, 4),
  never the budget. The minimality proof is the count of arrangements at each smaller depth, every one judged and none
  winning. Impact: FR-R02G2102-002; SC-R02G2102-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `BinaryGardensDifficulty` holds the
  witness length (actions), the worlds, the narrowest comfortable band (min over worlds of c_hi − c_lo, milliflux), the
  tightest window (max over worlds of W, ticks), the adjustable controls, the move space (Σ over adjustable controls of
  their other legal values), the arrangements judged at smaller depths, the solver work and the nearest miss (the
  smallest loss among the arrangements judged at smaller depths, the start included). The catalog in manifest order
  keeps R02-F24's standard `ProgressionRule` (drop at most 1, jump at most 3) on the witness length; band means must not
  fall (by construction 1, 2, 3, 3, 4: every level's witness length is its band's p, so the only changes are +1 at
  levels 21, 41 and 81). Impact: FR-R02G2102-003, 005; SC-R02G2102-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/binary-gardens/levels/NNN.witness.json` (the
  manifest's "Required artifact"), JSON schema 1 with sorted keys: number, the level's stored form (with its phase step
  when above 1), the actions (the plan, then `run`), the state digest after every action (16 hex characters of the
  SHA-256 of the arrangement and the actions spent), the play fingerprints after `begin` (and `dismissTutorial` when the
  level has one) and after each action, the terminal report (the truth metric: per world its integrated flux, its mean
  flux kept exact as the integral over 48 ticks, its longest lethal run against the tolerance, its longest comfortable
  window with its start tick against the requirement and its bloom result; the minimum squared star separation and its
  tick; the outcome), the counterexample (the depth one below the plan, the number of arrangements at that depth, none
  winning, and the nearest miss: its loss, its arrangement and its first failure with reason, world and tick or measure),
  the difficulty and the candidates skipped. A test rebuilds every witness and compares bytes; it writes the files only
  with `BINARY_GARDENS_WRITE_WITNESSES=1`. Decoding refuses newer schemas (`r02-g21.newer-schema`), damaged files and
  witnesses that no longer replay (`r02-g21.witness`). Impact: FR-R02G2102-004; SC-R02G2102-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<BinaryGardensPuzzle>.digest(id: "binary-gardens", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split into 20 groups of 5 levels so each runs under 10
  seconds on a debug host build (measured locally, not asserted on CI); generated levels are cached per process, since
  level n's neighbour rule needs level n − 1. New refusals: `generation(Int)` (`r02-g21.generation`) and
  `witness(String)` (`r02-g21.witness`). The independent check of SC-R02G2102-002 enumerates every action sequence
  shorter than the plan through the puzzle contract's moves, with no visited set and no loss ordering, on the two levels
  with the smallest move space in each band (ties by level number): none wins, and the number of arrangements first reached at each length equals the solver's count at that depth. Feature 501's existing tests stay unchanged (no budget widening is needed). The
  invariants INV-06 (content) and INV-12 (novelty), which feature 501 left to this feature, get named direct tests
  `testBinaryGardensContentBoundary` and `testBinaryGardensNoveltyBoundary`, each with a seeded neighbouring-input
  check. Impact: FR-R02G2102-006, 008; SC-R02G2102-002, 006, 007.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some setting of the two suns' rings, phases and brightness and
the orbit tilt, within the moves budget, gives a cycle in which every garden world keeps its stable illumination window,
blooms and never receives lethal light for too long. The game has proof of it for every level, and proof that no fewer
actions would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win on the run within the budget;
every action's resulting state equals the stored digest; the proof that fewer actions cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed and the light window is committed, **Then** the level
   is won within the budget.
2. **Given** any catalog level, **When** any arrangement reachable with fewer actions than the witness is run, **Then**
   none wins.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Why this priority**: reproducible content is what the witnesses, the digest and every later feature rely on.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

**Acceptance Scenarios**:

1. **Given** the manifest, **When** the catalog is built twice, **Then** every level and the digest are identical.
2. **Given** a manifest entry whose candidates are unsuitable, **When** the generator runs, **Then** it moves to the
   next candidate deterministically and records how many it skipped.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the actions the witness needs, the number of
worlds, the narrowest comfortable band, the tightest window, the adjustable controls and move space, the arrangements
searched and the solver's work. Harder bands mean more worlds with narrower bands and longer windows and more controls
working together, never faster reactions.

**Why this priority**: the five bands must feel like a progression.

**Independent Test**: band by band, the mean witness length does not fall; the catalog keeps the progression rule.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** the witness lengths are averaged per band, **Then** no band's mean is below the
   previous band's.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action, the
terminal light report (each world's integrated flux and survival) and the counterexample proof that fewer actions cannot
win, with the nearest miss and why it fails. Any edited or fake witness is caught.

**Why this priority**: the certificates are the release evidence for the content.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

**Acceptance Scenarios**:

1. **Given** the 100 witness files, **When** the witnesses are regenerated, **Then** every file matches byte for byte.
2. **Given** a witness file with one changed character, a newer schema or a damaged body, **When** it is decoded,
   **Then** it is refused with a named reason.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded at 64) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate whose starting arrangement already wins, or whose winning arrangement or start cannot keep the
  separation:** never emitted (the kernel refuses the first; the bounded redraws skip the second).
- **A world whose winning flux is so low that its comfortable floor would be 0:** the candidate is skipped; no bound
  is clamped silently. A lethal ceiling above the kernel's 200 000 milliflux cannot arise (at most 166 400 under the
  128 000-milliflux flux cap); the skip stays as a guard tested as a bound.
- **More than one minimal arrangement:** allowed; the witness is the one the solver finds in its fixed order.
- **An arrangement differing from the start in d controls but reachable only through a detour (the direct order breaks
  the separation):** it lies at its true, larger depth; the sweep follows only legal moves, so depths are exact.
- **Adjacent levels with the same ring radii and worlds:** the later candidate is skipped (FR-R02G2102-007).
- **A plan needing more actions than the budget:** not emitted (every band's p is far below its budget).
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **A phase action to a step off the level's phase grid:** refused by the play and absent from the solver's moves.
- **Flux exactly at a band or bloom bound, a lethal run exactly at the tolerance, a separation exactly at σ:** decided
  exactly by the kernel's integer rules; the generator and solver add no tolerance.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2102-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and budget, from a winning arrangement drawn first; only levels the kernel accepts and the solver certifies within the
  budget MAY be emitted.
- **FR-R02G2102-002**: A solver MUST find a minimal sequence of actions after which committing the light window wins, by
  a bounded sweep over arrangements (star rings, phases, luminosities, orbit tilt) by the number of actions from the
  start, each judged by feature 501's exact flux sampled at every tick of the cycle, with reachability checks skipping arrangements already reached at any depth, earlier in the same depth included
  (never pruning by outcome) and a light loss guiding the order, with its
  work bounded and counted, and MUST prove that no shorter sequence wins; every plan it reports MUST be replayed through
  the kernel's play.
- **FR-R02G2102-003**: Each level MUST carry difficulty metrics (witness length, worlds, narrowest comfortable band,
  tightest window, adjustable controls, move space, arrangements searched, solver work, nearest miss) derived from the
  level and the solver.
- **FR-R02G2102-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  terminal light report with each world's integrated flux and survival, counterexample proof with the nearest miss and
  its failure); damaged, newer and edited files MUST be refused.
- **FR-R02G2102-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness length never fall.
- **FR-R02G2102-006**: Invalid requests MUST be refused with stable reason codes `r02-g21.*`; existing code MUST change
  only additively; every new public name is documented; the reference regression passes.
- **FR-R02G2102-007**: Each emitted level MUST differ from its neighbours in the manifest (its fingerprint differs, and its ring radii and worlds are not both equal to the previous level's), so adjacent seeds give genuinely different puzzles.
- **FR-R02G2102-008**: The content invariant (every level has a replaying witness and its difficulty reflects the
  solver's actual work) and the novelty invariant (the mechanic is checked, not its name: every witness consists only of
  ring, phase, luminosity and tilt actions decided by received flux, and putting back any one changed control of the
  winning arrangement makes the run fail) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G2102-009**: A level MAY declare a phase step (a divisor of 48 up to 24); with it, star phases MUST lie on that
  grid and phase actions off it MUST be refused; a level without it MUST encode, fingerprint and play exactly as in
  feature 501.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget, control emphasis.
- **Band profile**: adjustable controls, rings, luminosity levels, phase step, tilt range, worlds, separation, star
  speed, margins, window slack, tolerance, plan length.
- **Minimality proof**: every arrangement reachable with fewer actions, none of which wins.
- **Solver result**: the actions, the work counted, the proof, the nearest miss.
- **Difficulty**: witness length, worlds, narrowest comfortable band, tightest window, adjustable controls, move space,
  arrangements searched, work, nearest miss.
- **Witness**: schema, the level's stored form, actions, per-action state digests, terminal light report,
  counterexample, difficulty, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2102-001**: All 100 catalog levels are won by replaying their witness and committing the light window, within
  the budget.
- **SC-R02G2102-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G2102-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G2102-004**: The mean witness length does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G2102-005**: For every level, no arrangement reachable with fewer actions than its witness wins; edited, newer
  and damaged witness files are refused.
- **SC-R02G2102-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.
- **SC-R02G2102-007**: The content and novelty boundary tests pass on all 100 levels with their neighbouring-input
  checks; a level with a phase step round-trips with its fingerprint and refuses an off-grid phase, and a level without
  one keeps its feature-501 fingerprint.

## Assumptions

- The 100 witness files live in `docs/games/binary-gardens/levels/NNN.witness.json`; they are regenerated only by a test
  run with an explicit opt-in and checked byte for byte on every other run.
- "Bounded coupled-orbit parameter sweep with sampling of received flux" is read as: the solver sweeps the arrangements
  reachable by actions (both stars share the binary's speed, so their orbits are coupled; rings, phases, luminosities and
  tilt are the parameters) by the number of actions from the start, bounded by the band's plan length and a counted work
  bound, judging each with the kernel's exact report, which samples every world's received flux at each of the 48 ticks
  of the cycle; the light loss only orders the sweep, so the first win found is minimal.
- The manifest's required concepts are covered by the kernel's rules, not by extra generator rules: `bounded
  inverse-square flux` by the clamp radius, `circumbinary orbit phase` by the 48-step phases, `planet survival integral`
  by the bloom band, `time window coverage` by the required window and `minimum separation` by σ (above 0 from band 3).
  The rows' "keep … outside the admissible zone" phrases (`divide by near-zero radius`, `numerical runaway flux`, `false
  realistic astrophysics claim`, `overlap masks star positions`, `same game as orbital counterpart`) are met by the
  clamp, the integer flux bounded at 64 000 milliflux per star, the toy-law wording of later features, the separation
  and the novelty test of FR-R02G2102-008.
- The control emphases `watch world` (inspection) and `commit light window` (the run) name no adjustable control; such
  entries draw every adjustable control by the shuffle. The emphasis is stored with the entry as provenance.
- Levels are presented, hinted and played through later features (R02-G21-03 … 07); this feature draws nothing.
- Accessibility and observability: every generated level is named in words by feature 501's kernel (stars, rings,
  phases, luminosities, tilt, worlds, flux against each band), so no level depends on colour; the witness files and the
  difficulty metrics are the content pipeline's observable record, and skipped candidates are counted, not hidden.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no star catalogue
  or third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G2102-001, 002 |
| Solver: bounded coupled-orbit parameter sweep with sampling of received flux | FR-R02G2102-002 |
| Truth metric: per-world integrated normalized flux and survival | FR-R02G2102-004 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G2102-004 |
| Difficulty metrics | FR-R02G2102-003, 005 |
| Different puzzle from adjacent seeds | FR-R02G2102-007 |
| Quantize controls to legal values | FR-R02G2102-009 |
| Invariants INV-06 (content) and INV-12 (novelty) | FR-R02G2102-008; SC-R02G2102-007 |
| Schema migration, error handling | FR-R02G2102-004, 006, 009 |
| Deterministic tests | SC-R02G2102-002, 003 |
| No Stage One breakage | FR-R02G2102-006 |

## Negative Requirements / Excluded scope

- No rendering, gestures, hints, adapter, catalog registration or persistence in this feature; no platform floating
  point or run-time trigonometry in the generator or solver; no timed search bound; no content beyond the 100 manifest
  entries; no device run before ImplementationLock-100.
