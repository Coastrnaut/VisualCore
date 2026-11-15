# Feature Specification: Light Maze — Phase 05 Content solvability and release QA

**Feature Branch**: `100-lm-p05-solver` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A13-P05 (legacy ledger) · ID namespace FR-A13-5##, SC-A13-5##, T-A13-5##

**Input**: User description: archived manual `apps/13-light-maze.md` §9 Phase 05 `/speckit-specify` prompt (verbatim
in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — glow and colour cues without hiding beam connectivity (built in
  A13-P02/P04, kept); regression fixture — the drawn beam's end points match the tracer's coordinates; graphics context
  ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/light-maze/visualcore-contract.json`): G-SOLVER (row M11) — a bounded search
  over the turnable tiles' orientations, using the existing tracer, that proves each shipping level solvable and records
  one solution; with it the release QA of the content (solvability, recorded solutions, licenses) that row M20 left
  for this phase.
- **Owner rulings:** short tests; audits and device runs in the device campaign ({device}); iOS 27 at phase gates;
  reference regression and iOS 26 at X-A13; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`BeamTracer.trace(_:)` gives `Beam.isSolved` for a board; `Board.applying(_:)` sets the turnable tiles' orientations
(nil for a wrong count); `Board.turnableIndices` lists them; `Board.problem` names an invalid board; tiles never move
(`Tile` has a cell but no move rule; the only state is `MazeState.orientations`); the catalog's largest level has 8
turnable tiles (`MazeCore.maxTurnable`), every level was designed for a single solution (LevelCatalog header);
`LicenseAudit.problems(_:)` lists missing author or license fields; the experience test `MazeGlowTests` already compares
drawn beam lines with tracer segments on five levels; no search or solver exists in any framework product (contract row
M11).

- Q: What does the search examine, in what order, and what is one "turn"? → A: Orientation sets of the turnable tiles
  only. A turn toggles one tile, so the turns of a set are the tiles whose orientation differs from the start. Order:
  by number of turns k = 0, 1, … n, and within k the tile combinations in lexicographic order of tile index; the first
  set whose traced board is solved is reported with its turns and the number of sets examined. Deterministic; at most
  2ⁿ sets.
- Q: What is the limit and what is refused? → A: At most 16 turnable tiles (65,536 sets); a board with more is refused
  `too-many-tiles`, an invalid board `invalid-board` (the board's own problem code is kept), both before any set is
  traced. A test builds a 16-tile board that is searched and a 17-tile board that is refused.
- Q: Where does the search live and is it shown to people? → A: In LightMazeCore as `Solver` and `ContentQA`
  (pure Swift, VisualCoreMath only), used by tests and the release QA; nothing in the experience calls them at run
  time, and no control or word changes (hints stay as A13-P04 built them).
- Q: What exactly does content QA check and report? → A: Per level: `unsolvable` (search finds no set), `wrong-solution`
  (the recorded solution does not light every target), `longer-solution` (recorded turns > fewest turns; no level has
  an allowance), `solved-start` (the start lights every target), `no-license` (LicenseAudit problem for the level);
  the result holds the level id, fewest turns, recorded turns and the failed check names in that order. Damaged-level
  fixtures are built in tests from catalog levels (a wall added on the path, a solution entry flipped, the start set to
  the solution, the license emptied).
- Q: How is "the drawn beam matches the tracer" checked? → A: An experience test builds the scene of each of the 20 levels
  at its start, with its recorded solution and with the search's answer, and requires the core beam lines' end points
  (in cells) to equal the tracer's segments one to one, within 1e-9; the drawing itself does not change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level is proven solvable by the rules (Priority: P1) 🎯

The owner can trust that each of the 20 levels can be solved, proven by a search that uses the same rules as play, and
that the search finds the fewest turns needed.

**Why this priority**: manual feature 6 ("built-in solvability test") and the release gate that no shipping level may be
unsolvable.

**Independent Test**: run the search on every level; replay its answer through the rules.

**Acceptance Scenarios**:

1. **Given** each shipping level, **When** the search runs from its start, **Then** it reports the level solvable with a
   set of orientations that lights every target, within its stated work limit.
2. **Given** the search's answer, **When** it is replayed as select and turn actions, **Then** the level reads solved,
   and no answer with fewer turns exists.
3. **Given** a board with no solution, **When** searched, **Then** it is reported unsolvable, never as solved.
4. **Given** a board beyond the search's limit, **When** searched, **Then** it is refused with a reason, without
   searching.

---

### User Story 2 - The content passes release QA (Priority: P1)

Before release, one check confirms for every level: it is solvable, its recorded solution is correct and uses the fewest turns, its start is not already solved, and its author and license are recorded.

**Why this priority**: the phase's name (release QA) and row M20's recheck.

**Independent Test**: run the content QA over the catalog; read one result per level.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** the QA runs, **Then** each of the 20 levels passes all checks and the report names the
   fewest turns for each.
2. **Given** a damaged level (unsolvable, a wrong recorded solution, a solved start, or missing license), **When** the QA
   runs, **Then** that level fails with the named check.

---

### User Story 3 - What is drawn is what the rules traced (Priority: P2)

The beam a person sees starts and ends exactly where the rules say, on every level, at the start and when solved.

**Why this priority**: the phase's regression fixture.

**Independent Test**: compare the drawn beam's end points with the tracer's for all levels.

**Acceptance Scenarios**:

1. **Given** each level at its start, solved by its recorded solution and solved by the search's answer, **Then** every
   drawn beam line's end points equal a tracer segment's end points and every tracer segment is drawn.

### Edge Cases

- **Several solutions with the fewest turns:** the search reports one, always the same (deterministic order).
- **A level whose start already solves it:** fails QA (nothing to do); the search reports zero turns.
- **The largest level in the catalog** (eight turnable tiles): searched in full within the limit.
- **A board at the limit's edge** (16 turnable tiles): searched; one more is refused.
- **An invalid board:** refused as invalid, never searched.

## Requirements *(mandatory)*

### Functional Requirements

**Search (story 1)**

- **FR-A13-501**: The search MUST examine orientation sets of the turnable tiles in a fixed order of increasing number
  of turns from the start, report the first set that lights every target (fewest turns), or report unsolvable after
  all sets, counting the sets it examined.
- **FR-A13-502**: The search MUST refuse, without searching, a board that is invalid (`invalid-board`) or has more
  turnable tiles than its limit (`too-many-tiles`: more than 16; at most 65,536 sets).

**Release QA (story 2)**

- **FR-A13-510**: The content QA MUST check every level for: solvable by the search; recorded solution lights every target;
  recorded solution's turns not more than the fewest (no level has an allowance); start not solved;
  author and license present; and report one result per level with the fewest turns.
- **FR-A13-511**: Each failing check MUST be named in the result (`unsolvable`, `wrong-solution`, `longer-solution`,
  `solved-start`, `no-license`).

**Drawing matches rules (story 3)**

- **FR-A13-520**: For every level at its start, solved by its recorded solution and solved by the search's answer, the
  drawn beam lines MUST equal the tracer's segments one to one.

### Key Entities

- **Search result**: solved (orientations, turns, sets examined), unsolvable (sets examined) or refused (reason).
- **Level QA result**: level id, fewest turns, recorded turns, failed checks (empty when passing).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A13-501**: 20 of 20 levels proven solvable; every answer replayed through actions solves its level.
- **SC-A13-502**: 100 % of unsolvable fixtures reported unsolvable; 100 % of boards over the limit refused unsearched.
- **SC-A13-503**: 20 of 20 levels pass content QA; each damaged-level fixture fails with its named check.
- **SC-A13-504**: 60 of 60 boards (20 levels × start, recorded solution, search answer) draw exactly the traced beam.
- **SC-A13-505**: The runner's scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The board, tracer, levels with recorded solutions, actions and presenter of A13-P01–P04 exist. Tiles turn but never
  move, so the search space is the orientations of the turnable tiles.
- A recorded solution is expected to use the fewest turns (each level was designed for a single solution); a longer one
  fails QA.

## Traceability

| Source | Requirement |
|---|---|
| Manual feature 6: built-in solvability test | FR-A13-501, 502, 510 |
| Phase 05 regression fixture: beam visual end points match the ray solver | FR-A13-520, SC-A13-504 |
| Phase 05 MVP: glow and colour cues kept | FR-A13-520 (drawing unchanged) |
| Row M20: licenses rechecked at release QA | FR-A13-510 |
| Contract gap G-SOLVER (M11) | FR-A13-501–511 |

## Negative Requirements

- No level generator, no random levels, no solver shown to the person (hints stay as A13-P04 built them); no change to
  the drawing; no network.
