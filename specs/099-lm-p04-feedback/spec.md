# Feature Specification: Light Maze — Phase 04 Hints, accessibility and visual polish

**Feature Branch**: `099-lm-p04-feedback` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A13-P04 (legacy ledger) · ID namespace FR-A13-4##, SC-A13-4##, T-A13-4##

**Input**: User description: archived manual `apps/13-light-maze.md` §9 Phase 04 `/speckit-specify` prompt (verbatim
in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP requirement — visual glow and colour cues without hiding beam connectivity
  (the capped glow of A13-P02 is kept; this phase adds the non-colour signs and contrast proof); all critical feedback
  stays legible without bloom, colour alone or animation (manual interaction rule); graphics context ownership stays
  solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/light-maze/visualcore-contract.json`): G-FEEDBACK (rows M09, M10, M17) —
  hints, the spoken board description, colour-plus-sign cues with contrast checks, and the success cue with sound and
  haptics, honouring Reduce Motion and Reduce Flashing. The solvability checker stays for A13-P05 (G-SOLVER).
- **Owner rulings:** short tests; system accessibility audits and device runs wait for the device campaign ({device});
  iOS 27 at phase gates; reference regression and iOS 26 at X-A13; every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ask for a hint (Priority: P1) 🎯

A person stuck on a level asks for a hint; the game points at one tile that has to turn and says where it is, without
solving the level for them.

**Why this priority**: the manual's third journey ("restart or request hint, then progress through a small curated
set") and the phase's name.

**Independent Test**: on fixture boards, ask for a hint; the named tile is one whose turn brings the board closer to the
level's recorded solution; following every hint solves the level.

**Acceptance Scenarios**:

1. **Given** a level not yet solved, **When** a hint is asked for, **Then** one tile that differs from the level's
   recorded solution is selected and named in words by row and column ("Hint: turn the mirror at row 2, column 3.").
2. **Given** a level, **When** hints are followed (hint, then turn) repeatedly, **Then** the level is solved in at most
   as many hints as it has turnable tiles.
3. **Given** a solved level, **When** a hint is asked for, **Then** it answers that the level is already solved and
   changes nothing.
4. **Given** a hint, **Then** it is a replayable action with a native control, like every other action.

---

### User Story 2 - Hear the board (Priority: P1)

A person using VoiceOver can hear the whole board on request: the level, every tile with its place and direction, the
path the beam takes, and which targets are lit and which are not; and is told when the level is solved.

**Why this priority**: manual feature 5 and the accessibility rule that no critical feedback depends on sight alone
(row M17).

**Independent Test**: read the description for fixture boards and compare with the board and the tracer's result.

**Acceptance Scenarios**:

1. **Given** a fixture board, **When** its description is read, **Then** it names the level, the board size, every
   emitter, wall, mirror, prism and target with its row and column (and direction or orientation), the beam's path as
   the cells where it turns or ends, and each target as lit or unlit.
2. **Given** any change to the board, **When** the description is read again, **Then** it matches the new board.
3. **Given** the board element, **Then** its accessible value is a short summary ("2 of 3 targets lit") and the full
   description is available through a native control.

---

### User Story 3 - Know when a level is solved (Priority: P1)

When the last target lights, the person notices: a short visual cue, a sound and a haptic tap, and spoken words naming
the level, the move count and the level that opened. The cue never flashes, respects the system's motion and flashing
settings, and plays once per solve.

**Why this priority**: manual feature 4's success feedback (row M09), left to this phase by A13-P03.

**Independent Test**: solve a level through actions; count the cues; repeat under Reduce Motion and Reduce Flashing.

**Acceptance Scenarios**:

1. **Given** a level one turn from solved, **When** the turn is made, **Then** exactly one success cue plays (visual,
   sound, haptic and words); further frames of the same solved board play none.
2. **Given** Reduce Motion, **Then** the visual cue appears without movement (a static solved frame); **given** Reduce
   Flashing, **then** no brightness change repeats.
3. **Given** a solved level is undone and solved again, **Then** the cue plays again, but haptics never exceed the
   framework's rate limit.

---

### User Story 4 - Colour is never the only cue (Priority: P2)

Every state the board shows — the beam, lit and unlit targets, the selected tile, the hinted tile, mirrors, prisms,
walls and emitters — differs by shape or sign as well as colour, and every colour stands out against the board.

**Why this priority**: manual feature 5 ("glow and colour cues without hiding beam connectivity") and row M10.

**Independent Test**: list each state's colour and sign; check that signs differ and contrasts pass.

**Acceptance Scenarios**:

1. **Given** the board's states, **Then** each has a distinct non-colour sign and no two states share both colour and
   sign.
2. **Given** each state's colour, **Then** its contrast against the board background is at least 3 : 1.
3. **Given** the glow, **Then** it never reaches past its stated cap, so the beam's path and the tiles stay visible.

### Edge Cases

- **A board already matching the solution but not solved:** cannot happen for shipping levels (the recorded solution
  lights every target); a hint on such a board says the level is solved or names no tile, never crashes.
- **A board solved in a way other than the recorded solution:** it is solved; hints are not offered.
- **A hint while a different tile is selected:** the selection moves to the hinted tile.
- **Sound off or the device muted, haptics unavailable:** the words and the visual cue still play; nothing fails.
- **VoiceOver off:** words are still given to the announcement sink; nothing depends on VoiceOver being on.
- **Suspension during a success cue:** the cue stops; it does not play again on resume.
- **Long descriptions:** a 7×7 board's description stays a few sentences per tile kind, bounded in length.

## Requirements *(mandatory)*

### Functional Requirements

**Hints (story 1)**

- **FR-A13-401**: A hint MUST select one turnable tile whose orientation differs from the level's recorded solution
  (the first in board order) and answer in words with its kind, row and column; on a solved board it MUST answer
  "already solved" and change nothing.
- **FR-A13-402**: The hint MUST be a replayable action with a native control and a gesture-free path; following hints
  MUST solve every shipping level within its count of turnable tiles.

**Spoken board (story 2)**

- **FR-A13-410**: A board description MUST name the level, the board size, every tile with its row, column and
  direction or orientation, the beam path (the cells where it turns or ends) and each target as lit or unlit, bounded
  in length.
- **FR-A13-411**: The board element's accessible value MUST summarise the targets lit; a native control MUST speak the
  full description.

**Success cue (story 3)**

- **FR-A13-420**: On the transition to solved, exactly one success cue MUST play: a visual cue, a sound made in code,
  a success haptic within the framework's rate limit, and spoken words naming the level, the move count and the
  level that opened.
- **FR-A13-421**: Under Reduce Motion the visual cue MUST be static; under Reduce Flashing no brightness change may
  repeat; the cue MUST stop on suspension and not replay.

**Signs and contrast (story 4)**

- **FR-A13-430**: Every board state MUST carry a distinct non-colour sign, checked by the framework's colour-plus-sign
  check with no problems.
- **FR-A13-431**: Every state colour MUST reach a contrast of at least 3 : 1 against the board background; the glow cap
  of A13-P02 MUST be kept.

### Key Entities

- **Hint**: the hinted tile (index among turnable tiles) and its words; none when solved.
- **Board description**: the summary and the full text derived from the board and the tracer's result.
- **Success cue**: the solve it belongs to (level, move count), its visual, sound, haptic and words, played once.
- **State style**: each board state's colour and non-colour sign.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A13-401**: Following hints solves 100 % of the 20 levels, each within its number of turnable tiles; 0 hints
  change a solved board.
- **SC-A13-402**: 100 % of fixture board descriptions name every tile, the beam's turning and end cells and every
  target's state.
- **SC-A13-403**: Exactly 1 success cue per solve transition; 0 under repeated frames; 0 repeated brightness changes
  under Reduce Flashing; 0 movement under Reduce Motion.
- **SC-A13-404**: 0 colour-plus-sign problems; 100 % of state colours at contrast ≥ 3 : 1 against the background.
- **SC-A13-405**: The runner's scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The board, tracer, levels with recorded solutions, actions, gestures, presenter, progress and undo of A13-P01–P03
  exist; the framework's announcement, haptic and sound planners, colour-plus-sign check and contrast ratio are reused.
- A hint uses the level's recorded solution, not a search; the search (solver) is A13-P05.
- Hints do not change the best move count; the count stays the number of turns.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 MVP: glow and colour cues without hiding beam connectivity | FR-A13-430, 431 |
| Interaction rule: critical feedback legible without bloom, colour alone or animation | FR-A13-410, 421, 430 |
| Journey 3: restart or request a hint | FR-A13-401, 402 |
| Manual feature 4: success feedback | FR-A13-420, 421 |
| Manual feature 5: glow and colour cues | FR-A13-430, 431 |
| Contract gap G-FEEDBACK (M09, M10, M17) | FR-A13-401–431 |

## Negative Requirements

- No solver or search in this phase; no hint that solves the whole level at once; no scoring penalty for hints.
- No recorded or downloaded sound files, no flashing, no confetti or particle bursts; no network, accounts or sharing.
- No system accessibility audit before the device campaign.
