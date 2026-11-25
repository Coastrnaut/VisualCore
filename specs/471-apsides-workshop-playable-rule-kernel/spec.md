# Feature Specification: R02-G18-01 — Apsides Workshop: playable rule kernel

**Feature Branch**: `471-apsides-workshop-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G18-01 (migration ledger, game feature of experience R02-G18) · ID namespace FR-R02G1801-###,
SC-R02G1801-###, T-R02G1801-###

**Input**: User description: the archived R02-G18-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Apsides Workshop, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/471-apsides-workshop-playable-rule-kernel`; FR-R02G1801-###,
  SC-R02G1801-###, T-R02G1801-###.
- **Packaging (ADR-0009):** Apsides Workshop is experience R02-G18 (`r02-g18.apsides-workshop`, free) inside the
  single VisualCore app. The source's `Apps/ApsidesWorkshop` and `Packages/GameModules/ApsidesWorkshopCore` become the
  experience module `Packages/ExperiencesRound02/ApsidesWorkshop`; this feature adds its pure Core with tests. Catalog
  registration, adapter and renderer come in later features of R02-G18 and its gate X-R02-G18.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 78 (the catalog's "78
  solver-certified stages") is a milestone inside the levels of R02-G18-02. **Device-only items:** none (pure logic).
  **Owner-only items:** none.
- **Exactness:** the source's law (M = E − e·sin E, inverted by a bounded Newton iteration with a bisection fallback;
  r = a(1 − e·cos E); area swept by quadrature) is evaluated in deterministic integer fixed-point arithmetic, so every
  device computes the same orbit positions bit for bit; every rule (sector membership, swept-area shares, apsis
  checks, contact with an exclusion planet) is then decided exactly on those integer positions. The catalog's
  0.008333 s timestep is the presentation clock of later features and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G18-02 can certify levels).
- **Model:** feature 461 (Celestial Eclipse Lab's rule kernel) for structure, stored form, records and refusals.

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
461's answers where the games agree (stages, stored form, records, refusal codes, puzzle contract). Facts checked in
code (read-only, 2026-11-25): Celestial Eclipse Lab's kernel (`CelestialEclipseLabLevel`, `CelestialEclipseLabPlay`,
`CelestialEclipseLabError` with codes `r02-g17.level`, `.action`, `.budget`, `.stage`, `.stale`, `.newer-schema`,
`.malformed`) keeps every limit as an integer range, fingerprints levels with SHA-256 of a canonical text and
implements R02-F23's `PuzzleRules` (`VisualCoreSimulation`).

- Q: What exactly is an orbit, and how is Kepler's equation solved so every device agrees? → A: the star sits at the
  origin of a sky of lattice units (one lattice unit = 256 sky units; sky bound 64 lattice units; star radius 2).
  An orbit is a size a of 8 … 48 lattice units, an eccentricity step k of 0 … 15 (e = k/20, so 0 … 0.75) and a
  periapsis direction step d of 0 … 23 (15° each, counterclockwise from +x). It is valid when its periapsis distance
  a(20 − k)/20 is at least 3 lattice units and its apoapsis distance a(20 + k)/20 at most 64, tested exactly as
  a(20 − k) ≥ 60 and a(20 + k) ≤ 1280. The period is T ticks (even, 16 … 96); at tick t the mean anomaly is
  M = 2πt/T. All anomalies and trigonometric values are integers in fixed point with 2^30 as one, computed by integer
  sine, cosine and square root only. Newton's iteration starts at E = M + e·sin M and takes at most 8 steps, stopping
  when the residual |M − (E − e·sin E)| is at most 2^−24; if it has not stopped, or leaves the bracket [M − e, M + e],
  48 bisection steps on that bracket decide E. Every tick's residual MUST be at most 2^−22. The position is
  (a(cos E − e), a·√(1 − e²)·sin E) turned by 15d° and rounded to whole sky units (half away from zero); its distance
  r = a(1 − e·cos E) is reported. Periapsis is tick 0 and apoapsis tick T/2. Impact: FR-R02G1801-002, 003, 014;
  SC-R02G1801-003.
- Q: What are the sectors and the swept shares? → A: 8 sectors of 45°, sector s covering the directions from 45s°
  (included) to 45(s + 1)° (excluded), counterclockwise from +x; a point's sector is decided exactly from the signs of
  x and y and the comparison of |x| with |y|. The quadrature is one triangle per tick, star → P(t) → P(t + 1) (with
  P(T) = P(0)), whose doubled area is the integer cross product; each triangle counts for the sector of P(t). A sector's
  share is its area over the whole orbit's area in tenths of a percent, rounded down (0 … 1000). The periapsis lies in
  sector ⌊d/3⌋ at the distance a(20 − k) in twentieths of a lattice unit; the apoapsis in sector ⌊(d + 12)/3⌋ mod 8 at
  a(20 + k). Impact: FR-R02G1801-001, 004.
- Q: How are the targets ordered and judged, and what counts as contact? → A: a level has 1 … 6 targets, each a sweep
  (sector, lowest and highest share 0 … 1000, both included) or an apsis target (periapsis or apoapsis, sector, nearest
  and farthest distance in twentieths, both included). Each target has an event tick: a sweep, the first tick whose P(t)
  lies in its sector (T if none); periapsis 0; apoapsis T/2. Contact: a planet (centre −64 … 64 lattice units on each
  axis, radius 1 … 8, never overlapping the star) is struck when its centre's closest distance to a segment P(t) → P(t +
  1) is strictly smaller than its radius, decided exactly in integers. Playing first walks the ticks: the first contact
  (lowest tick, then lowest planet) fails `contact`; otherwise it walks the targets in order: a target with an event
  tick earlier than the previous target's fails `order`; a sweep outside its band fails `share`; an apsis in another
  sector fails `apsis-sector`, at a distance outside its range `apsis-distance`; all met wins. A failure names the
  planet or target and its tick. Impact: FR-R02G1801-005; SC-R02G1801-004.
- Q: Which actions exist and how does a level live and how is it stored? → A: `periapsis(k, d)` sets the eccentricity
  and direction steps (at least one different) and `size(a)` the size; each spends one action and is refused
  `r02-g18.action` when out of range, unchanged or making the orbit invalid, `r02-g18.budget` when no action is left.
  `play` spends nothing and ends the level (won or failed); undo and redo restore tunings and, from failed, undo returns
  to playing with the orbit before the play. The budget is 1 … 24. As feature 461: stages loading → tutorial → playing
  ⇄ paused → won or failed → result; begin, dismissTutorial, pause and resume are their own record kinds; each record
  carries the schema, the level seed, an index, the kind, the action and the fingerprints before and after, and replay
  refuses a record of another level or a broken chain (`r02-g18.malformed`); `.stage` and `.stale` as there. The stored
  form is JSON schema 1 with sorted keys (id, seed, difficulty 1 … 5, period, planets, targets, starting orbit, budget,
  tutorial, fingerprint = SHA-256 of a canonical text); a damaged or edited form is refused `r02-g18.malformed`, a newer
  one `r02-g18.newer-schema`, an invalid level `r02-g18.level`. Impact: FR-R02G1801-006, 007, 008, 009, 011.
- Q: What does the kernel report after every action, and what is the puzzle contract? → A: the orbit report: the
  positions by tick, the share of every sector, the periapsis and apoapsis readings (sector, distance), the largest
  Kepler residual, every target's deviation (a share's distance outside its band, 0 inside; an apsis's sector match and
  distance outside its range), the first contact, the first unmet target and the predicted outcome of a play now, with
  words for each ("sector 3 swept 18.4 %, needs 15.0 to 20.0 %", "periapsis in sector 2 at 6.5 units"); the play's
  position words name the orbit, actions left and the next target. The puzzle contract (R02-F23): the position is the
  orbit (a, k, d), the moves are the tunings legal from it, the goal test is that the predicted play wins; certifying
  levels (R02-G18-02) searches orbits. Impact: FR-R02G1801-010, 013, 014.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Shape the orbit so it sweeps the prescribed sky (Priority: P1) 🎯

A player sees a star at the centre of a miniature sky divided into sectors, an orbiter on an elliptical orbit around
it, exclusion planets to avoid and an ordered list of targets: sky sectors the orbit must sweep with a prescribed share
of its area, and apsis targets (where the closest and farthest points of the orbit must lie). The player tunes the
orbit — its eccentricity and the direction of its periapsis with one knob, its size with another — then plays one
revolution: when every target is met, in order, and the orbit touches no exclusion planet, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known orbit wins when played; after every action the predicted
positions, swept shares, apsis readings and outcome equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known orbit, **When** it is set and the revolution is played, **Then** the level is won.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - An exclusion planet is struck, or a target is missed (Priority: P1)

Playing the revolution fails the level when the orbit comes into contact with an exclusion planet, when a sector's
swept share lies outside its tolerance, when an apsis lies in the wrong sector or at the wrong distance, or when the
targets are not met in their order. Each failure names its reason, the target or planet and the tick; the player can
undo the play and tune the orbit again.

**Independent Test**: scripted sequences end failed with the named reason on the play.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **An orbit that would dip into the star or leave the sky:** the tuning is refused without cost.
- **A tuning equal to the current orbit, or outside its ranges:** refused without cost.
- **An orbit that only grazes an exclusion planet (the closest distance exactly equal to its radius):** no contact;
  contact needs a strictly smaller distance.
- **A sector the orbit never enters:** its share is 0 and its event tick is the end of the revolution (T).
- **A swept share exactly on a tolerance bound:** inside the tolerance.
- **A point exactly on a sector boundary:** it belongs to the sector that begins at that boundary, by a fixed rule.
- **A circular orbit (eccentricity zero):** its periapsis direction is defined by the knob's direction, so apsis
  targets still have one answer.
- **The action budget spent:** further tunings are refused, playing is still allowed.
- **A level already solved at load:** never accepted; every level needs at least one tuning to win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo from failed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1801-001**: A level MUST define the sky (its sectors around the star and its bound), the orbiter's period in
  ticks, the exclusion planets (each a centre and a radius), the ordered targets (sector sweeps with a share tolerance
  and apsis targets with a sector and a distance range), the starting orbit, the action budget and whether it shows a
  tutorial.
- **FR-R02G1801-002**: An orbit MUST be given by its size, its eccentricity and the direction of its periapsis, each
  chosen from fixed steps; an orbit whose closest point would enter the star or whose farthest point would leave the
  sky is invalid and never accepted.
- **FR-R02G1801-003**: The orbiter's position at every tick of one revolution MUST follow Kepler's equation from
  periapsis (equal steps of mean anomaly per tick), inverted by a bounded Newton iteration with a bisection fallback,
  computed deterministically so every device gets the same positions; the Kepler residual of every tick MUST stay within
  a stated bound.
- **FR-R02G1801-004**: The area swept in each sector over the revolution MUST be computed by quadrature over the ticks
  and reported as a share of the whole orbit's swept area.
- **FR-R02G1801-005**: Playing the revolution MUST end the level: won exactly when the orbit makes no contact with any
  exclusion planet and every target is met in its order; otherwise failed with the reason (contact, a share outside its
  tolerance, an apsis missed, the order broken), the target or planet and the tick.
- **FR-R02G1801-006**: A tuning MUST change the eccentricity and periapsis direction (one knob) or the size (the other)
  and spend one action; every action MUST be validated (ranges, orbit validity, stage, budget, previous fingerprint) and
  refused without change when invalid.
- **FR-R02G1801-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1801-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1801-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1801-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1801-011**: Invalid requests MUST be refused with stable reason codes `r02-g18.*`; existing modules
  unchanged.
- **FR-R02G1801-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1801-013**: Every sector, target, planet and measure MUST be identifiable without colour vision: the kernel
  names them in words (sector numbers, shares in percent, distances, ticks, actions left, the next target).
- **FR-R02G1801-014**: The truth metric MUST be computed exactly and reported after every action: the largest Kepler
  residual of the revolution and, for every target, its deviation (a share's distance from its tolerance band, an
  apsis's sector and distance against its range), with the first unmet target and the predicted outcome.

### Key Entities

- **Level**: sky, period, exclusion planets, targets, starting orbit, budget, tutorial flag, fingerprint.
- **Orbit**: size, eccentricity step, periapsis direction step.
- **Exclusion planet**: centre, radius.
- **Target**: a sector sweep (sector, share tolerance) or an apsis target (periapsis or apoapsis, sector, distance
  range).
- **Orbit report**: positions by tick, swept share per sector, apsis readings, Kepler residual, target deviations, first
  contact, first unmet target, outcome.
- **Action**: periapsis knob (eccentricity, direction), size, play, undo, redo.
- **Play**: stage, orbit, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1801-001**: For 500 seeded constructed levels the known orbit wins and every refused action is refused with
  its named reason.
- **SC-R02G1801-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1801-003**: Over 500 seeded orbits, every position, Kepler residual, sector membership, swept share, apsis
  reading, contact decision and outcome equals an independent computation, and every residual is within its bound.
- **SC-R02G1801-004**: Failure happens on the play with the reason named, including a share one unit either side of a
  tolerance bound, an apsis one unit either side of its distance range and a planet one unit inside and outside contact.
- **SC-R02G1801-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1801-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Drag periapsis knob" is the tuning of eccentricity and periapsis direction together; "semi-major axis" is the size
  tuning; "turn time crank" is a preview of the orbiter's tick (presentation only); "play orbit" is playing the
  revolution.
- "A sequence of prescribed sky sectors" is the ordered target list; the order is the order in which the orbiter,
  starting at periapsis, reaches each target during the revolution.
- "Kepler residual and swept-area deviation" is the exact truth metric of FR-R02G1801-014.
- Levels and their certification (bounded search over eccentricity and orientation samples) come in R02-G18-02;
  drawing in R02-G18-03; gestures in R02-G18-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (tunings, play, budget) | FR-R02G1801-002, 006, 007, 008 |
| Kepler's equation with bounded Newton and bisection fallback | FR-R02G1801-003 |
| Area swept via quadrature | FR-R02G1801-004 |
| Exact win/failure evaluation (targets in order, tolerance, exclusion planets) | FR-R02G1801-005 |
| Truth metric: Kepler residual and swept-area deviation | FR-R02G1801-014; SC-R02G1801-003 |
| Puzzle contract for certification | FR-R02G1801-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G18-02; INV-11 is superseded by the free tier) | FR-R02G1801-012 |
| Accessibility (colour independence) | FR-R02G1801-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no platform floating point in the rules; no device run before ImplementationLock-100.
