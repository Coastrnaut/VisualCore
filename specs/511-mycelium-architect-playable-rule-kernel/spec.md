# Feature Specification: R02-G22-01 — Mycelium Architect: playable rule kernel

**Feature Branch**: `511-mycelium-architect-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G22-01 (migration ledger, game feature of experience R02-G22) · ID namespace FR-R02G2201-###,
SC-R02G2201-###, T-R02G2201-###

**Input**: User description: the archived R02-G22-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Mycelium Architect, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/511-mycelium-architect-playable-rule-kernel`; FR-R02G2201-###,
  SC-R02G2201-###, T-R02G2201-###.
- **Packaging (ADR-0009):** Mycelium Architect is experience R02-G22 (`r02-g22.mycelium-architect`, free) inside the
  single VisualCore app. The source's `Apps/MyceliumArchitect` and `Packages/GameModules/MyceliumArchitectCore` become
  the experience module `Packages/ExperiencesRound02/MyceliumArchitect`; this feature adds its pure Core with tests.
  Catalog registration, adapter and renderer come in later features of R02-G22 and its gate X-R02-G22.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 84 (the catalog's "84
  solver-certified stages") is a milestone inside the levels of R02-G22-02: the canonical catalog is the archived
  100-level manifest (`python3 scripts/planning_index.py levels --experience R02-G22`: 20 levels in each of bands
  1 … 5, moves budgets 8 … 19, control emphases `steer growth`, `commit graph`, `place nutrient`, `seed filament` and
  `block toxin`, 20 levels each). **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Exactness:** the source's law (each growing tip chooses the direction of maximum nutrient gradient minus curvature
  and obstacle penalties; graph cap 2048 nodes) is evaluated on a square lattice in integer arithmetic: the nutrient
  field, the gradient, the penalties, the branch weights and every rule are whole numbers with fixed tie-breaks, so
  every device grows the same network bit for bit. The catalog's 0.016667 s timestep is the presentation clock of later
  features; the kernel counts growth pulses and never reads a clock.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G22-02 can certify levels).
- **Model:** feature 501 (Binary Gardens' rule kernel) and feature 491 (Mushroom Weather's) for structure, stored
  form, records and refusals.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following
features 491 and 501 where the games agree (stages, stored form, records, refusal codes, puzzle contract). Facts
checked in code (read-only, 2026-11-27): Binary Gardens' kernel refuses with `r02-g21.level`, `.action`, `.budget`,
`.stage`, `.stale`, `.newer-schema` and `.malformed` (and `.generation`, `.witness` from its feature 502), keeps every
limit as an integer range, fingerprints levels with SHA-256 of a canonical text and implements R02-F23's puzzle
contract; its action budget is 1 … 24. No `MyceliumArchitect` module exists yet in `Packages/ExperiencesRound02`. The
archived manifest of R02-G22 has moves budgets 8 … 19.

- Q: What is the lattice, how are directions numbered and what is the nutrient field? → A: a board of W × H cells
  (W and H 4 … 32), cells named (column, row) from (0, 0) at the top left, row increasing downward. Eight directions
  numbered clockwise from north: 0 N (0, −1), 1 NE (1, −1), 2 E (1, 0), 3 SE (1, 1), 4 S (0, 1), 5 SW (−1, 1), 6 W
  (−1, 0), 7 NW (−1, −1). Distance is the Chebyshev distance d = max(|Δcolumn|, |Δrow|). With strength s (1 … 8) and
  reach R (1 … 16), the nutrient value of a cell is f(c) = Σ over unconsumed nutrients n of s · max(0, R − d(c, n));
  every value is a whole number below 2³¹. Obstacles are rocks, blockers and the outside of the board. Impact:
  FR-R02G2201-001, 003; SC-R02G2201-003.
- Q: How exactly does a tip choose, branch and stop? → A: a tip at cell c with heading h may step in direction k to
  cell t when t is on the board, not a rock or blocker, not already in the network, and, for a diagonal k, not both
  orthogonal cells it passes between are obstacles (no corner cutting); a toxic cell is admissible (entering it fails
  the run). Its score is (f(t) − f(c)) − κ·turn(h, k) − ο·obs(t), with turn(h, k) = min(|k − h|, 8 − |k − h|) in
  0 … 4, obs(t) the number of obstacles among t's eight neighbours (0 … 8), and penalties κ and ο each 0 … 8. The
  highest score wins; ties go to the smaller turn, then the lower direction number. A tip with no admissible direction
  or whose best score is below 0 goes dormant for good. Each pulse moves the growing tips in ascending tip number; a
  tip sees cells grown earlier in the same pulse; a tip made during a pulse first moves in the next pulse. The run
  starts with one tip per seed at the root, numbered 1, 2, … in ascending seed direction, heading its seed direction.
  A tip that steps onto an unconsumed nutrient consumes it (the field changes from the next choice on) and a new tip
  with the next unused number is made on that cell with heading (k + 2) mod 8 (a quarter turn clockwise); the parent
  keeps heading k. After a step, a tip's heading is the direction it stepped. Impact: FR-R02G2201-004; SC-R02G2201-003.
- Q: How are branch weight, the budget, the limit, the pulses and reaching a terminal measured? → A: an orthogonal
  segment weighs 2 and a diagonal one 3 (an integer stand-in for 1 : √2). The nutrient budget is 2 … 4094 and the
  weight limit 2 … budget; the run walks pulses 1 … P (P 1 … 128) and ends early when no tip is growing. Before each
  step the kernel checks the step's weight: if the total would exceed the budget the run fails `starved` at that
  pulse, tip and target cell, and nothing is grown; otherwise the step is grown and, if the target is toxic, the run
  fails `toxic` there. Each grown cell keeps its parent, so the network is a tree rooted at the root and has at most
  1 + 4094 / 2 = 2048 nodes. A terminal is reached when a tip steps onto it; tips may grow on through it. A terminal's
  path weight is the sum of segment weights from the root along the tree. After growth: the lowest-numbered terminal
  not reached fails `unreached`; otherwise a total weight above the limit fails `overweight`; otherwise won. Impact:
  FR-R02G2201-005, 006, 015; SC-R02G2201-004.
- Q: Which counts, actions and refusals exist? → A: 1 … 6 terminals, any number of rocks and toxins, 0 … 8 fixed
  nutrients, up to 6 placed nutrients, up to 6 placed blockers, up to 4 seeds with 0 … 4 starting seeds (starting
  seeds are locked); at least one placement or seed must be available. Actions: `nutrient(cell)`, `blocker(cell)`
  (on an empty cell: not rock, toxin, root, terminal, fixed nutrient or already placed), `clear(cell)` (a placed
  nutrient or blocker), `seed(direction)` (a direction not yet seeded) and `unseed(direction)` (a seed the player
  added). Each spends one action and is refused `r02-g22.action` when out of range, unchanged, locked or over a count,
  `r02-g22.budget` when no action is left; the budget is 1 … 24. `run` ("commit graph", "advance growth pulses")
  spends nothing and ends the level; inspecting a cell is the report and changes nothing. Undo and redo restore
  arrangements and, from failed, undo returns to playing with the arrangement before the run. A seed is a heading, not
  a forced first step: the tip chooses its first step by score. Impact: FR-R02G2201-001, 002, 007, 012.
- Q: How does a level live, how is it stored and what does the report say? → A: as features 491 and 501: stages
  loading → tutorial → playing ⇄ paused → won or failed → result; begin, dismissTutorial, pause and resume are their
  own record kinds; each record carries the schema, the level seed, an index, the kind, the action and the
  fingerprints before and after; replay refuses a record of another level or a broken chain (`r02-g22.malformed`);
  `r02-g22.stage` (an action in the wrong stage) and `r02-g22.stale` (a previous fingerprint that does not match). The
  stored form is JSON schema 1 with sorted keys (id, seed, difficulty 1 … 5, width, height, root, terminals, rocks,
  toxins, fixed nutrients, strength, reach, the two penalties, the three placement limits, starting seeds, pulses,
  nutrient budget, weight limit, action budget, tutorial, fingerprint = SHA-256 of a canonical text, cell lists in
  ascending (row, column) order); a damaged or edited form is refused `r02-g22.malformed`, a newer one
  `r02-g22.newer-schema`, an invalid level `r02-g22.level`. The report after every action holds the field, every tip's
  step by pulse with its score, the network with the pulse each cell was grown, the node count, the total weight
  against budget and limit, each terminal's reach pulse and path weight, the first toxic entry, the first failure and
  the predicted outcome, with words for each ("tip 2 at pulse 7: east to (9, 4), score 12", "terminal 1 reached at
  pulse 11, path weight 23", "branch weight 41 of 48, budget 60"). The puzzle contract (R02-F23): the position is the
  arrangement, the moves are the actions legal from it, the goal test is that the predicted run wins. Impact:
  FR-R02G2201-008, 009, 010, 011, 015.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Feed the network so its glowing veins reach every terminal (Priority: P1) 🎯

A player sees a dark cave floor with rocks, pools of toxin, a root of living fungus and a few glowing terminals that
must be joined to it. The player seeds filaments from the root in chosen directions, places nutrients that pull
growth toward them, and places blockers that turn growth away from toxins, then advances the growth pulses: each
growing tip creeps toward the richest neighbouring ground, preferring to keep its heading and to keep off rocks, and
branches where it feeds. When every terminal is joined to the root and the network's total branch weight is within the
level's limit, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known arrangement wins when growth runs; after every action the
predicted network, field, weights, connections and outcome equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known arrangement, **When** it is set up and growth runs, **Then** the level is won.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.
3. **Given** a cell, **When** the player inspects it, **Then** its nutrient value, its occupant and whether the
   predicted network reaches it are reported in words and nothing changes.

### User Story 2 - The network strays into toxin, runs out of nutrient or misses a terminal (Priority: P1)

Running growth fails the level when a tip grows into a toxic cell, when the network's branch weight would exceed the
nutrient budget, when a terminal is not reached once growth ends, or when every terminal is reached but the branch
weight is above the level's limit. Each failure names its reason, the pulse, the tip or terminal and the cell or the
measured value; the player can undo the run and rearrange.

**Independent Test**: scripted sequences end failed with the named reason on the run.

**Acceptance Scenarios**:

1. **Given** an arrangement whose growth enters a toxic cell, **When** growth runs, **Then** the level fails `toxic`
   naming the pulse, the tip and the cell.
2. **Given** a failed run, **When** the player undoes, **Then** play resumes with the arrangement before the run.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A cell off the board, on a rock, a toxin, the root, a terminal, a fixed nutrient or an already placed item:**
  placing there is refused without cost.
- **Clearing a cell that holds nothing the player placed:** refused without cost.
- **More nutrients, blockers or seeds than the level allows, or a second seed in the same direction:** refused without
  cost.
- **A tip with no admissible neighbour** (all off the board, rock, blocker, already in the network or a corner cut
  between two obstacles): the tip goes dormant; it is not a failure.
- **Equal scores:** the smaller turn wins, then the lower direction number, so growth is never ambiguous.
- **A best score below zero:** the tip goes dormant.
- **Two tips choosing the same cell in one pulse:** the lower-numbered tip moves first; the cell is then in the
  network and the other tip chooses again among the rest.
- **A tip entering a nutrient:** the nutrient is consumed and a new tip starts there a quarter turn clockwise; a
  consumed nutrient no longer pulls.
- **A step that would exceed the budget onto a toxic cell:** `starved`, since the budget is checked before the step.
- **Branch weight exactly at the nutrient budget or exactly at the weight limit:** allowed; failure needs one more.
- **No growing tip left before the last pulse:** growth ends early and the network is judged.
- **The action budget spent:** further arrangement actions are refused; running is still allowed.
- **A level already won at load, or with nothing the player can place or seed:** never accepted.
- **Actions after the end:** every action is refused once the level is won or failed, except undo from failed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2201-001**: A level MUST define a rectangular board of cells, the root cell, 1 … 6 terminal cells, the rock
  cells, the toxic cells, the fixed nutrients, the nutrient strength and reach, the curvature and obstacle penalties,
  the numbers of nutrients, blockers and seeds the player may place, the starting seeds, the number of growth pulses,
  the nutrient budget and the branch-weight limit, the action budget and whether it shows a tutorial. A level is
  refused when a value is out of range, two features share a cell, the weight limit exceeds the nutrient budget,
  nothing can be placed or seeded, or the starting arrangement already wins.
- **FR-R02G2201-002**: The arrangement MUST consist of the placed nutrients, the placed blockers and the seeded
  directions at the root; each placement MUST be on an empty cell and within the level's counts.
- **FR-R02G2201-003**: The nutrient value of every cell MUST be a whole number computed from every unconsumed nutrient
  by a fixed distance rule, so every device gets the same field.
- **FR-R02G2201-004**: Each growth pulse MUST move every growing tip, in a fixed order, one cell in the direction of
  greatest score: the gain in nutrient value minus the curvature penalty times the turn from its heading minus the
  obstacle penalty times the obstacles around the target cell, with fixed tie-breaks; a tip with no admissible
  neighbour or only negative scores MUST go dormant; a tip entering a nutrient MUST consume it and branch once.
- **FR-R02G2201-005**: Every grown segment MUST add its whole-number branch weight; the network MUST never exceed 2048
  nodes.
- **FR-R02G2201-006**: Running growth MUST end the level: failed at the first move into a toxic cell (reason: toxic)
  or the first move that would take the branch weight above the nutrient budget (reason: starved), naming the pulse,
  tip and cell; otherwise, once growth ends, failed when a terminal is not in the network (reason: unreached, the
  lowest-numbered such terminal) or the branch weight is above the limit (reason: overweight); otherwise won.
- **FR-R02G2201-007**: An action MUST place a nutrient, place a blocker, clear a placed item, seed a direction or
  remove a seed, and spend one action; every action MUST be validated (cells, counts, change, stage, budget, previous
  fingerprint) and refused without change when invalid. Running and inspecting spend nothing.
- **FR-R02G2201-008**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST
  reproduce every state.
- **FR-R02G2201-009**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result); actions while paused are refused, never partly applied.
- **FR-R02G2201-010**: Levels MUST have a versioned stored form (schema 1) with a fingerprint; damaged, edited and
  newer forms MUST be refused; a later schema MUST migrate schema 1 forward.
- **FR-R02G2201-011**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G2201-012**: Invalid requests MUST be refused with stable reason codes `r02-g22.*`; existing modules
  unchanged.
- **FR-R02G2201-013**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G2201-014**: Every cell, tip, terminal, item and measure MUST be identifiable without colour vision: the
  kernel names them in words (cells by column and row, directions by compass name, tips and terminals by number,
  nutrient values, weights, pulses, actions left).
- **FR-R02G2201-015**: The truth metric MUST be computed exactly and reported after every action, as the kernel's
  observability: root-to-terminal connectivity (each terminal reached or not, with the pulse it was reached and its
  path weight from the root), the total branch cost against the budget and the limit, the forbidden-zone hits (the
  first toxic entry, if any), the grown network by pulse, the node count, the first failure and the predicted outcome.

### Key Entities

- **Level**: board, root, terminals, rocks, toxins, fixed nutrients, strength, reach, penalties, placement counts,
  starting seeds, pulses, nutrient budget, weight limit, action budget, tutorial flag, fingerprint.
- **Arrangement**: placed nutrients, placed blockers, seeded directions.
- **Tip**: number, cell, heading, growing or dormant.
- **Network**: cells grown from the root, segments with weights, the pulse each cell was reached.
- **Growth report**: field, network by pulse, connectivity, branch cost, toxic hits, first failure, outcome.
- **Action**: nutrient, blocker, clear, seed, unseed, run, undo, redo.
- **Play**: stage, arrangement, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2201-001**: For 500 seeded constructed levels the known arrangement wins and every refused action is
  refused with its named reason.
- **SC-R02G2201-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G2201-003**: Over 500 seeded runs, every field value, tip move, branch, weight, connection and outcome equals
  an independent computation, and no network exceeds 2048 nodes.
- **SC-R02G2201-004**: Failure happens on the run with the reason named, including a branch weight one unit either
  side of the budget and of the limit, a toxic cell one cell either side of a tip's path and a terminal one cell
  beyond the grown network.
- **SC-R02G2201-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G2201-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Place nutrients and blockers" are the nutrient and blocker actions, "undo edits" is undo and clear, "advance
  growth pulses" is the run; the manifest's `place nutrient`, `block toxin`, `seed filament` (seeding a direction at
  the root), `steer growth` (the steering effect of placements and seeds) and `commit graph` (the run) map to them.
- "Required terminals connected with at most specified branch weight" is the won rule; "network enters toxic volume or
  exceeds nutrient budget" is the toxic and starved failures; a terminal left unreached and an overweight network are
  the honest failures of the won rule's two halves.
- "Root-to-terminal connectivity, total branch cost and forbidden-zone hits" is the exact truth metric of
  FR-R02G2201-015.
- The recursive L-systems and hyphae bloom of the signature shader are presentation; the judged network is the
  lattice growth of this kernel.
- Levels and their certification (graph shortest path plus the deterministic growth heuristic and the topology check)
  come in R02-G22-02; drawing in R02-G22-03; gestures in R02-G22-04.
- Mycelium Architect grows a network by local gradient choices toward placed attractors, not by routing light (Binary
  Gardens, R02-G21) or flowing water; its moves and its solution representation are its own.
- The game design is the project's own archived design; the code is original; no third-party data is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (nutrients, blockers, seeds, run, budget) | FR-R02G2201-002, 007, 008, 009 |
| Tip chooses max nutrient gradient minus curvature and obstacle penalties | FR-R02G2201-003, 004 |
| Graph cap 2048 nodes | FR-R02G2201-005 |
| Exact win/failure evaluation (terminals within branch weight; toxic or budget) | FR-R02G2201-006 |
| Truth metric: connectivity, total branch cost, forbidden-zone hits | FR-R02G2201-015; SC-R02G2201-003 |
| Puzzle contract for certification | FR-R02G2201-011 |
| Schema migration, error handling | FR-R02G2201-010, 012 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G22-02; INV-11 is superseded by the free tier) | FR-R02G2201-013 |
| Accessibility (colour independence) | FR-R02G2201-014 |
| Observability | FR-R02G2201-015 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no platform floating point in the rules; no device run before ImplementationLock-100.
