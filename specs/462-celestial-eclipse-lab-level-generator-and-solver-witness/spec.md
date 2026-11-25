# Feature Specification: R02-G17-02 — Celestial Eclipse Lab: level generator and solver witness

**Feature Branch**: `462-celestial-eclipse-lab-level-generator-and-solver-witness` (spec directory only; work on
`main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G17-02 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1702-###,
SC-R02G1702-###, T-R02G1702-###

**Input**: User description: the archived R02-G17-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Celestial Eclipse Lab, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/462-celestial-eclipse-lab-level-generator-and-solver-witness`;
  FR-R02G1702-###, SC-R02G1702-###, T-R02G1702-###.
- **Packaging (ADR-0009):** experience R02-G17 (`r02-g17.celestial-eclipse-lab`, free) in the one app; this feature
  extends the pure `CelestialEclipseLabCore` of feature 461. No app target, bundle identifier, scheme or store listing.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G17`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 19, control emphases `inspect timeline`, `commit order`, `set orbital phase`, `adjust
  inclination` and `schedule eclipse`, 20 each). The prompt's "content count 74" is a milestone figure, as for the
  earlier round-two games.
- **Model:** feature 452 (Starlit Cartouche's content pipeline) for manifest, generator, solver, witness files, digest
  and progression, adapted to the eclipse rules of feature 461: a move is a phase change, and the run ends the level.

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
452's answers where the games agree. Facts checked (read-only, 2026-11-25): R02-G17-01's `CelestialEclipseLabLevel` (2 …
6 bodies, orbits of 4 … 24 positions, coordinates −32 … 32, radius 1 … 8, depth-ordered pairs, horizon 8 … 96, target
1 … 6, budget 1 … 24, starting phases that must not win), `CelestialEclipseLabSky` (exact overlap, visibility,
intervals, judge), `CelestialEclipseLabPlay` and `CelestialEclipseLabRules`; R02-F24's
`PuzzleCatalog.digest(id:identities:)` and the standard `ProgressionRule` (drop at most 1, jump at most 3);
`SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries (bands 1 … 5 × 20, moves
budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19 by band, five control emphases, 20 each); every manifest budget lies
inside the kernel's 1 … 24, so the kernel needs no change. The ranges below were measured before they were written
down: a prototype of this generator and solver on the real kernel, run over the real 100 manifest entries (release
build), certified every entry within candidate index 4, with at most 10 291 settings judged per candidate, in 0.57 s
for all 100; witness lengths by band averaged 1.65, 2.15, 3.25, 3.40 and 4.40 (ranges 1 … 2, 2 … 3, 3 … 4, 3 … 4,
4 … 5) with no progression drop or jump; one entry's first certified candidate repeated the previous level's target sequence (hence
the neighbour rule). A debug build judged 20 band-5 entries in 7.0 s with the pair-interval table below (27 s with the
kernel's whole-sky timeline per setting).

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, budget, control
  emphasis) are a table in `CelestialEclipseLabManifest` with their provenance. Candidate c of entry n draws from
  `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the body count (band profile); a
  depth rank per body (a Fisher–Yates shuffle of 0 … count − 1, from the last index down); for each body its period
  (4 … 8), centre x and y (−8 … 8 each), semi-axes a and b (3 … 10 each), direction (forward or backward) and tilt
  (−1 … 1), its orbit positions being (cx + round(a·cos), cy + round(b·sin), 4·rank − 12 + round(tilt·sin)) from a fixed
  integer table of cos and sin × 1000 for each period (rounded half away from zero; no floating point), then its
  radius (1 … 4); body 0 is fixed, the others movable; the horizon (band profile); the winning phases (one per body,
  0 … period − 1); the target count (band profile), the target being the first that many eclipse events of the winning
  phases' timeline, each with window open = first − 0 … 2 (at least 0) and close = first + 0 … 2 (at most horizon − 1);
  the number of bodies to move away (band profile, at most the movable count), each a drawn movable body given a drawn
  different phase. Band profiles (bodies, targets, horizon, moved, plan range): band 1 (3, 1 … 2, 24 … 32, 2, 1 … 2),
  band 2 (3 … 4, 2 … 3, 28 … 36, 3, 2 … 3), band 3 (4 … 5, 2 … 3, 32 … 40, 4, 3 … 4), band 4 (5 … 6, 3 … 4, 36 … 44, 4,
  3 … 4), band 5 (6, 3 … 4, 40 … 48, 5, 4 … 5). Budget = the manifest's; ids `celestial-eclipse-lab-NNN`; tutorial on
  levels 1 … 3; difficulty = band. A candidate is skipped when the level rules refuse it (including starting phases
  that already win), when the winning timeline has fewer events than the target count, when its target sequence of
  (front, back) pairs equals the previous level's (FR-R02G1702-007), or when the solver does not certify a minimal plan
  inside its band's plan range within its work bound; at most 256 candidates, then `generation(n)`. The catalog is
  therefore built in manifest order. Impact: FR-R02G1702-001, 007; SC-R02G1702-001, 003, 004.
- Q: How does the solver find a minimal plan, and what proves nothing shorter wins? → A: a later phase change of the
  same body overrides an earlier one, so the settings reachable with at most d phase changes are exactly the phase
  vectors that differ from the start on at most d movable bodies; the solver searches them by depth d = 1, 2, … (the
  start itself does not win): at each depth, the subsets of d movable bodies in lexicographic order of body numbers,
  and within a subset the new phases in lexicographic order (each 0 … period − 1 except the starting phase). Each
  setting is judged with a pair-interval table built once per level: for every pair and every pair of phases, the
  pair's eclipse intervals over the horizon by the kernel's exact overlap and visibility rules; a setting's intervals
  are the merge of its pairs' lists in timeline order (first tick, front, back), walked by the kernel's judge. The
  first winning setting ends the search; the plan is its phase changes in body order, then `run`, replayed through the
  kernel's play, whose timeline must agree. Work = settings judged, counted and bounded at 60 000; over the bound, or
  past the band's upper plan length, the candidate is skipped. The minimality proof is the count of settings at each
  smaller depth, every one judged and none winning. Impact: FR-R02G1702-002; SC-R02G1702-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `CelestialEclipseLabDifficulty` holds the
  witness length (phase changes), the bodies, the movable bodies, the target eclipses, the eclipse events of the
  winning timeline, the settings judged at smaller depths and the solver work. The catalog in manifest order keeps
  R02-F24's standard `ProgressionRule` (drop at most 1, jump at most 3) on the witness length; band means must not fall
  (measured above). Impact: FR-R02G1702-003, 005; SC-R02G1702-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/celestial-eclipse-lab/levels/NNN.witness.json`,
  JSON schema 1 with sorted keys: number, the level's stored form, the actions (the phase changes, then `run`), the
  state digest after every action (16 hex characters of the SHA-256 of the phases and the actions spent), the play
  fingerprints after `begin` (and `dismissTutorial` when the level has one) and after each action, the terminal
  timeline (each interval's front, back, first and last tick and visibility class, and the matched count), the
  counterexample (the depth one below the plan and the number of settings at that depth, none winning), the difficulty
  and the candidates skipped. A test rebuilds every witness and compares bytes; it writes the files only with
  `CELESTIAL_ECLIPSE_LAB_WRITE_WITNESSES=1`. Decoding refuses newer schemas, damaged files and witnesses that no longer
  replay. Impact: FR-R02G1702-004; SC-R02G1702-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<CelestialEclipseLabRules>.digest(id: "celestial-eclipse-lab", identities:)` over the 100 level
  fingerprints in manifest order, pinned in a test. Certification tests are split into groups of 10 levels so each runs
  under 10 seconds on a debug host build (measured locally, not asserted on CI); generated levels are cached per
  process. New refusals: `generation(Int)` (`r02-g17.generation`) and `witness(String)` (`r02-g17.witness`). The
  independent check of SC-R02G1702-002 judges, with the kernel's own whole-sky timeline (no pair table), every setting
  with fewer phase changes than the plan on the two levels with the fewest bodies in each band: none wins. Impact:
  FR-R02G1702-006; SC-R02G1702-002, 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some phase changes within the moves budget make the target
eclipses happen in order, each inside its window, with no other eclipse first. The game has proof of it for every
level, and proof that no fewer phase changes would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win on the run within the budget;
every action's resulting state equals the stored digest; the proof that fewer phase changes cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed and the clock is run, **Then** the level is won within
   the budget.
2. **Given** any catalog level, **When** any setting reachable with fewer phase changes than the witness is run,
   **Then** none wins.
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

Each level carries difficulty metrics from the solver's actual result: the phase changes the witness needs, the
bodies, the target eclipses, the eclipse events the timeline holds, the settings searched and the solver's work.
Harder bands mean longer sequences and more orbits to phase together, never faster reactions.

**Why this priority**: the five bands must feel like a progression.

**Independent Test**: band by band, the mean witness length does not fall; the catalog keeps the progression rule.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** the witness lengths are averaged per band, **Then** no band's mean is below the
   previous band's.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action, the
terminal timeline (the ordered eclipse intervals with their visibility classes) and the counterexample proof that
fewer phase changes cannot win. Any edited or fake witness is caught.

**Why this priority**: the certificates are the release evidence for the content.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

**Acceptance Scenarios**:

1. **Given** the 100 witness files, **When** the witnesses are regenerated, **Then** every file matches byte for byte.
2. **Given** a witness file with one changed character, a newer schema or a damaged body, **When** it is decoded,
   **Then** it is refused with a named reason.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate whose starting phases already win:** never emitted (the kernel refuses it).
- **More than one minimal setting:** allowed; the witness is the one the solver finds in its fixed order.
- **Adjacent levels with the same target sequence:** the later candidate is skipped (FR-R02G1702-007).
- **A plan needing more phase changes than the budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Touching discs or an eclipse on a window's edge:** decided exactly by the kernel's integer rules; the generator
  and solver add no tolerance.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1702-001**: A generator MUST build each catalog level deterministically from its manifest number, seed,
  band and budget; only levels the kernel accepts and the solver certifies within the budget MAY be emitted.
- **FR-R02G1702-002**: A solver MUST find a minimal sequence of phase changes after which running the clock wins, with
  its work bounded and counted, and MUST prove that no shorter sequence wins; every plan it reports MUST be replayed
  through the kernel's play.
- **FR-R02G1702-003**: Each level MUST carry difficulty metrics (witness length, bodies, movable bodies, target
  eclipses, timeline events, settings searched, solver work) derived from the level and the solver.
- **FR-R02G1702-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  terminal timeline with visibility classes, counterexample proof); damaged, newer and edited files MUST be refused.
- **FR-R02G1702-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness length never fall.
- **FR-R02G1702-006**: Invalid requests MUST be refused with stable reason codes `r02-g17.*`; existing code MUST change
  only additively; every new public name is documented; the reference regression passes.
- **FR-R02G1702-007**: Each emitted level MUST differ from its neighbours in the manifest (its fingerprint and its
  target sequence are not those of the previous level), so adjacent seeds give genuinely different puzzles.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget, control emphasis.
- **Minimality proof**: every phase setting reachable with fewer phase changes, none of which wins.
- **Solver result**: the phase changes, the work counted, the proof.
- **Difficulty**: witness length, bodies, movable bodies, target eclipses, timeline events, settings searched, work.
- **Witness**: schema, the level's stored form, actions, per-action state digests, terminal timeline, counterexample,
  skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1702-001**: All 100 catalog levels are won by replaying their witness and running the clock, within the
  budget.
- **SC-R02G1702-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G1702-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1702-004**: The mean witness length does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1702-005**: For every level, no setting reachable with fewer phase changes than its witness wins; edited,
  newer and damaged witness files are refused.
- **SC-R02G1702-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes
  in under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/celestial-eclipse-lab/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "Analytical circle/ellipse overlap interval enumeration and phase search" is read as: the kernel's exact integer
  overlap test enumerates each pair's eclipse intervals for every pair of phases, and the solver searches phase settings
  by the number of phase changes from the start, so the first win found is minimal. Orbits are lattice positions, so
  "ellipse" means an orbit's shape, not a continuous curve.
- Levels are presented, hinted and played through later features (R02-G17-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G1702-001, 002 |
| Solver: analytical overlap interval enumeration and phase search | FR-R02G1702-002 |
| Truth metric: ordered interval overlap timestamps and visibility classification | FR-R02G1702-004 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G1702-004 |
| Difficulty metrics | FR-R02G1702-003, 005 |
| Different puzzle from adjacent seeds | FR-R02G1702-007 |
| Schema migration, error handling | FR-R02G1702-004, 006 |
| Deterministic tests | SC-R02G1702-002, 003 |
| No Stage One breakage | FR-R02G1702-006 |
