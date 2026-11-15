# Feature Specification: Light Maze — Phase 03 Core levels and progress

**Feature Branch**: `098-lm-p03-progress` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A13-P03 (legacy ledger) · ID namespace FR-A13-3##, SC-A13-3##, T-A13-3##

**Input**: User description: archived manual `apps/13-light-maze.md` §9 Phase 03 `/speckit-specify` prompt (verbatim
in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — deterministic ray propagation with reflection and a finite bounce cap
  (built in A13-P01, kept as the rule every level and move is checked against); regression fixture — all shipping levels
  have at least one verified solution; graphics context ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/light-maze/visualcore-contract.json`): G-LEVELS (level select with unlock
  progression, the per-level move list with undo and restart, the saved progress document, and the content license
  record of the 20 levels). Hints and success feedback stay for A13-P04 (G-FEEDBACK); the solvability checker for
  A13-P05 (G-SOLVER).
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A13; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
Physics Playground's `ExperimentStore` keeps files in the experience's `ExperienceStorage` (`write(_:to:)` replaces a file
atomically; reading never writes; refusals `damaged`, `newer-version` and storage error codes; an in-memory variant
without storage), and Tiny Worlds' `WorldStore` follows it; `LightMazeExperience.make(id:storage:…)` receives the
launch's storage but does not use it yet; `MazeState` is schema 1 (level index, orientations, selection) inside
`MazeCore` with a `MigrationChain(currentVersion: 1)`; the scenario manifest's fixtures replay `level.select`,
`tile.select` and `tile.turn` from a fresh state.

- Q: Where does progress live, and does it change what the engine accepts? → A: Progress is the device's file
  `progress.json` in the experience's storage, read and written by a `ProgressStore` (as `ExperimentStore`) owned by the
  presenter, outside the engine state, so replays and the runner's fixtures are unchanged by it. Locking is enforced
  where a person chooses a level: the Level menu lists locked levels as disabled with "locked", Next level is disabled
  when the next level is locked, and a refused choice is answered "Level 7 is locked; solve level 6 first."; the engine's
  `level.select` stays as it is.
- Q: What is the progress document? → A: Schema 1, sorted-key JSON of at most 16 KB: `{"levels":[{"best":n|null,
  "id":"lm-01","open":true,"solved":false},…],"schema":1}` with exactly the 20 catalog ids in order; level 1 always
  open; a solved level is open and has best 1…999, an unsolved one has best null; anything else, unknown ids or a
  different count is `damaged`; a file above 16 KB is `too-large`; a higher schema is `newer-version`; a refused file is reported and left untouched and
  play continues from fresh progress in memory (not written until the next real change, which then replaces it).
- Q: How are moves, undo and restart kept? → A: State schema 2 = schema 1 plus `moves` (each: tile index, orientation
  before, orientation after), at most 64 (the oldest dropped beyond that); `tile.turn` appends; a new action
  `move.undo` restores the last move's "before" orientation exactly and removes it (refused with `a13.no-moves` when
  empty); `level.reset` is the restart (starting orientations, moves emptied); `level.select` empties the moves; the
  migration 1 → 2 adds no moves. Native controls: Undo (`undo`, value "N moves") and Restart (`reset-level`).
- Q: When is a level recorded as solved? → A: When a drawn frame shows the current level solved after it was not (the
  presenter compares with the last frame), progress marks it solved, sets best = min(best, moves count, at least 1),
  opens the next level and saves once; reaching a solved state by undo counts with the remaining moves. Without storage
  (tests) progress is kept in memory.
- Q: How are the shipping levels proven? → A: A core test replays each level's recorded solution as `level.select`,
  `tile.select` and `tile.turn` from a fresh state and reads it solved (all 20); an experience test solves levels 1–3 in
  order through the presenter and reads levels 1–3 solved, level 4 open and level 5 locked; the content license record
  of A13-P01 stays the license proof of G-LEVELS.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unlock levels by solving them (Priority: P1) 🎯

A person starts with the first level open; solving a level opens the next one. The level list shows each level as
locked, open or solved, with the fewest moves it took.

**Why this priority**: the manual's second and third journeys ("complete three introductory levels", "progress through
a small curated set") and feature 4.

**Independent Test**: solve levels by actions; read the progress and the level list.

**Acceptance Scenarios**:

1. **Given** fresh progress, **When** the list is read, **Then** level 1 is open and levels 2–20 are locked; choosing a
   locked level is refused with a reason.
2. **Given** level 1, **When** it is solved, **Then** it is marked solved with its move count and level 2 opens.
3. **Given** a level solved before, **When** it is solved again in fewer moves, **Then** the best count drops; more
   moves never raise it.

---

### User Story 2 - Undo and restart (Priority: P1)

A person can take back the last turn, one at a time, back to the level's start, or restart the level at once; the board
and beam return exactly to how they were.

**Why this priority**: feature 4's undo and restart.

**Independent Test**: turn tiles, undo, compare boards and beams with the recorded earlier states.

**Acceptance Scenarios**:

1. **Given** several turns, **When** undone one by one, **Then** each undo restores the exact earlier orientations and
   beam, and undo at the start is refused.
2. **Given** turns, **When** the level is restarted, **Then** the starting orientations return and the move list empties.

---

### User Story 3 - Progress survives closing the app (Priority: P1)

A person's opened and solved levels and best counts are kept on the device and come back the next time; a damaged or
newer progress file never loses the app's ability to play.

**Independent Test**: save, reopen, compare; feed damaged, truncated and newer files.

**Acceptance Scenarios**:

1. **Given** progress, **When** saved and reopened, **Then** it is identical.
2. **Given** a damaged, truncated or newer progress file, **When** opened, **Then** it is reported (as are oversized files), the file is left
   untouched and play starts from fresh progress in memory.
3. **Given** a write interrupted midway, **Then** the previous file stays intact.

---

### User Story 4 - Every shipping level is proven (Priority: P2)

The owner can trust that each of the 20 levels has at least one solution that the rules verify, replayed through the
same actions a person uses.

**Independent Test**: replay each level's recorded solution as actions from its start; the level reads solved.

**Acceptance Scenarios**:

1. **Given** each level, **When** its recorded solution is replayed as select and turn actions, **Then** it is solved
   and progress records it.

### Edge Cases

- **Solving by undo:** a state reached by undo that is solved counts as solved (with the moves made, undos not counted).
- **Moves cap:** the move list is bounded; beyond it the oldest moves can no longer be undone (stated cap).
- **Switching levels:** the move list belongs to the level and is cleared when another level opens.
- **Restoring a saved session:** the level, orientations and moves restore; progress is the device's file, not the
  session.
- **A progress file naming unknown levels or impossible counts:** refused as damaged.
- **Reset of the app's data:** removes the progress file; play starts fresh.

## Requirements *(mandatory)*

### Functional Requirements

**Progression (story 1)**

- **FR-A13-301**: Progress MUST hold, per level, whether it is open and solved and its best move count; level 1 MUST be
  open from the start and solving a level MUST open the next.
- **FR-A13-302**: Choosing a locked level MUST be refused with a reason; the level list MUST show locked, open and
  solved with best counts, each with a label and value.

**Moves (story 2)**

- **FR-A13-310**: Every accepted turn MUST be recorded in the level's move list (bounded); undo MUST restore the exact
  previous orientations and beam; restart MUST return the starting orientations and empty the list.
- **FR-A13-311**: Undo and restart MUST be replayable actions with native controls.

**Saved progress (story 3)**

- **FR-A13-320**: Progress MUST be saved in the experience's own storage with atomic writes, versioned, with damaged,
  truncated and newer files reported and left untouched.
- **FR-A13-321**: The session state MUST hold the level, orientations and moves (schema 2, with schema 1 migrated).

**Proof (story 4)**

- **FR-A13-330**: Every shipping level MUST be replayed from its start through actions to a solved state in tests.

### Key Entities

- **Level progress**: level id, open, solved, best moves.
- **Progress document**: schema version, level progress for the 20 levels.
- **Move**: turnable tile index, orientation before and after.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A13-301**: 100 % of levels open only after the previous one is solved; 0 locked levels can be chosen.
- **SC-A13-302**: 100 % of undos restore the exact previous orientations and beam; restart returns the start.
- **SC-A13-303**: Saved progress reopens identical; damaged, truncated and newer files: 0 crashes, 100 % reported,
  files unchanged; an interrupted write leaves the previous file byte-identical.
- **SC-A13-304**: All 20 levels are solved by replaying their recorded solutions through actions.
- **SC-A13-305**: The runner's nine scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The board, tracer, levels, actions, gestures and presenter of A13-P01–P02 exist; experience storage with atomic writes
  is reused as in Tiny Worlds and Physics Playground.
- A best count is the number of turns accepted on the level since it was opened or restarted, undone turns subtracted.

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 MVP: deterministic propagation with a bounce cap (kept) | FR-A13-310, 330 |
| Regression fixture: all shipping levels have a verified solution | FR-A13-330, SC-A13-304 |
| EGL/context ownership in the VisualCore host | FR-A13-302 |
| Manual feature 4: level select, unlock progression, undo and restart | FR-A13-301–311 |
| Journeys 2–3: introductory levels, progressing through a curated set | FR-A13-301, 302 |
| Contract gap G-LEVELS | FR-A13-301–330 |

## Negative Requirements

- No accounts, cloud sync, sharing or level editor; no hints or celebrations in this phase; no network.
