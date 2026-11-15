# Feature Specification: Neon Arcade — Phase 04 Scores and accessibility

**Feature Branch**: `078-na-p04-scores` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A10-P04 (legacy ledger) · ID namespace FR-A10-4##, SC-A10-4##, T-A10-4##

**Input**: User description: archived manual `apps/10-neon-arcade.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — touch steering with configurable sensitivity; regression fixture — the
  high score is not corrupted by abrupt termination; graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/neon-arcade/visualcore-contract.json`): G-HIGHSCORES (a crash-safe local
  high-score table over the experience's own storage) and G-STEERINPUT (touch-steering sensitivity with the native
  controls as an equal alternative), both app-local. No VisualCore change is planned.
- **Accessibility pass** (constitution A10 Accessibility): every control labelled, the game's state spoken and
  announced, every canvas gesture with a native alternative, text controls following Dynamic Type; proved by unit and
  UI tests on iOS 27 (system accessibility audits wait for the device campaign, owner ruling of 2026-11-13).
- **Owner rulings:** short tests; iOS 27 at phase gates; reference regression and iOS 26 at X-A10; every Spec Kit step
  runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`ExperienceStorage.write(_:to:)` replaces a file atomically (readers see the complete old or new content; temporary
files are hidden and a refused write leaves the stored file intact); `AnnouncementPlanner(minimumInterval:)` collapses
announcements within an interval; `ExperienceFeedback.announce(_:kind:)` routes to VoiceOver; `GestureAlternatives`
checks that every canvas gesture has a native control; Neon Arcade's drag uses a fixed reach of 1.5 units (A10-P01) and
its snapshot is schema 3; Digital Aquarium's UI tests (`Apps/VisualCore/Tests/UI/DigitalAquarium`) open a candidate
with `-vcCandidates` and find controls by `experience.<id>.<name>` identifiers.

- Q: What are the five sensitivity steps and where are they kept? → A: Reaches 2.5, 2.0, 1.5 (default), 1.0 and 0.6
  units of finger offset for full steering, steps 0 (gentle) … 4 (sharp); action `settings.sensitivity [0…4]` (whole
  numbers, otherwise `a10.invalid-choice`); snapshot schema 4 adds `sensitivity` (migration 3 → 4 sets 2) and
  `runNumber` (counts the runs started, migration sets 1 for a run in progress).
- Q: What does the high-score table hold and how is it saved? → A: `HighScoreTable` (board version 1, at most 10
  `HighScoreEntry(score, wave, run)` with score 1…9,999,999 and wave ≥ 1, highest score first, equal scores by earlier
  run) stored as JSON in the experience's storage file `high-scores.json` with the atomic write; no date, name or
  device data. The table also remembers the last run number entered, so a run's end is entered once. A file that does
  not decode, has another board version or breaks the rules is reported ("high scores could not be read") and left in
  place until the next completed run writes a valid table.
- Q: How is "killed while saving" proved? → A: Host and simulator tests write a table, then simulate an interrupted
  save by leaving a partial temporary file beside it (and by truncating a copy of the JSON), and read back the last
  complete table; a truncated file on its own is reported as damaged. The scenario manifest adds a fixture that ends a
  run (the table write itself happens in the presenter, outside the digest).
- Q: What is announced, how often and in which words? → A: Through `AnnouncementPlanner(minimumInterval: 1.0)` and
  the host's feedback route: "Hit, n lives left", "Wave n", "Game over, score s", "New high score s" (the last replaces
  "Game over" when both apply); pickups are never announced; repeated events within a second collapse into the latest.
- Q: What do the UI tests cover? → A: A new `Apps/VisualCore/Tests/UI/NeonArcade/` suite (support file plus one test
  class) on the iOS 27 phone: open Neon Arcade as a candidate, Start, steer left and right with the buttons, pause and
  resume, change the sensitivity, find the best-score label on the title screen; run in its own UI chunk.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Steering that suits my hands (Priority: P1) 🎯

A person who finds the steering too twitchy or too slow picks one of five sensitivity steps; dragging then moves the
player more or less for the same finger movement, the choice is kept, and the left/right buttons remain an equal way
to play.

**Why this priority**: the manual's Phase 04 MVP (version 0.1 feature 04) and gap G-STEERINPUT.

**Independent Test**: for each step, the same finger offset gives a different, bounded steering value, ordered from
gentle to sharp; the step survives saving and restoring; the native controls reach the same steering range.

**Acceptance Scenarios**:

1. **Given** sensitivity step n, **When** the finger is held a fixed distance from the player, **Then** the steering
   value equals that distance divided by step n's reach, clamped to full steering.
2. **Given** a chosen step, **When** the game is saved and restored, **Then** the step is the same.
3. **Given** VoiceOver or no touch on the field, **When** the person uses the left, right and straight controls,
   **Then** the player can reach every position the drag can.

---

### User Story 2 - My best runs are kept (Priority: P1)

When a run ends, its score joins a local table of the best ten runs (score and wave), shown on the game-over and
title screens; the table survives quitting, and nothing — not even the app being killed while it saves — can damage
it.

**Why this priority**: the manual's Phase 04 regression fixture and gap G-HIGHSCORES; version 0.1 feature 03 "local
scores".

**Acceptance Scenarios**:

1. **Given** a finished run whose score beats the lowest entry or a table with fewer than ten entries, **When** the run
   ends, **Then** the run is in the table at its rank, highest first, and the table is saved.
2. **Given** a save interrupted part-way (the app is killed), **When** the table is read again, **Then** it is the last
   complete table.
3. **Given** a damaged or newer table file, **When** it is read, **Then** the problem is reported, the game still
   plays with an empty table, and the next completed run writes a valid table.
4. **Given** the same run, **When** its end is processed twice (for example after restoring a saved game-over
   screen), **Then** it appears in the table once.

---

### User Story 3 - Playable without seeing every pixel (Priority: P2)

A person using VoiceOver hears the screen, score, lives and wave, hears announcements when they are hit, collect an
orb, a wave starts or the run ends, and can start, pause, steer, restart and change settings with labelled controls.

**Why this priority**: constitution A10 Accessibility; version 0.1 features 04 and 06.

**Acceptance Scenarios**:

1. **Given** VoiceOver, **When** the game changes (hit, wave, game over, new high score), **Then** a short announcement
   is made, at most one per second, never for every orb.
2. **Given** any screen, **When** the controls are inspected, **Then** every control has a label and a value or hint.
3. **Given** large text sizes, **When** the controls are shown, **Then** their text grows with the setting and stays
   readable.

### Edge Cases

- **Equal scores:** a new score equal to an entry ranks below it (earlier runs first).
- **A run that scores 0:** not entered.
- **Storage full or refused:** the table stays in memory for the session and the problem is reported once; play
  continues.
- **Sensitivity changed mid-run:** takes effect from the next finger movement; it is a recorded action, so replays
  stay exact.
- **Restoring an older saved game:** sensitivity takes its default step.
- **VoiceOver announcements during a burst of events:** collapsed into one; the spoken description stays complete.
- **Where the scores live and how they go away:** the table is the experience's own local data (no copy elsewhere, not
  in backups of other apps); the app's existing reset of an experience's data removes it, and the A10-P06 privacy
  document lists it.

## Requirements *(mandatory)*

### Functional Requirements

**Sensitivity (G-STEERINPUT)**

- **FR-A10-401**: The game MUST offer five sensitivity steps with a reach in game units each, ordered from gentle to
  sharp, and map a finger's offset from the player to steering by the chosen reach, clamped to full steering.
- **FR-A10-402**: The chosen step MUST be a recorded setting saved with the game; the native left, right and straight
  controls MUST stay an alternative to every canvas gesture.

**High scores (G-HIGHSCORES)**

- **FR-A10-410**: A versioned high-score table MUST hold at most ten entries (score, wave, run number), highest first,
  equal scores in order of arrival, and reject entries with a score of 0 or non-finite numbers.
- **FR-A10-411**: The table MUST be saved in the experience's own storage with a write that leaves either the old or the
  new table, read back on opening, and a damaged or newer file MUST be reported without stopping play.
- **FR-A10-412**: A finished run MUST be entered exactly once, even if its end is seen again after a restore.
- **FR-A10-413**: The title and game-over screens MUST show the best scores, and a new entry MUST be marked.

**Accessibility**

- **FR-A10-420**: Hits, wave starts, game over and a new high score MUST be announced, at most one announcement per
  second; pickups are not announced.
- **FR-A10-421**: Every control MUST have a label and a value or hint; text controls MUST follow Dynamic Type; the
  spoken description MUST name the screen, score, lives, wave and the best score.
- **FR-A10-422**: UI tests on iOS 27 MUST open Neon Arcade, start a game, steer with the buttons, pause, change the
  sensitivity and see the game-over or title table through accessibility labels.

### Key Entities

- **Sensitivity step**: index 0…4 and its reach.
- **High-score entry**: score, wave, run number.
- **High-score table**: version and up to ten entries.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A10-401**: For each of the five steps the same finger offset gives steering ordered gentle → sharp, every value in
  −1…1; the step round-trips through save and restore.
- **SC-A10-402**: 100 % of simulated interrupted saves leave a readable table equal to the last complete one; 100 % of
  damaged or newer files are reported and play continues.
- **SC-A10-403**: Tables never exceed ten entries, stay ordered, and each run appears at most once.
- **SC-A10-404**: Announcements: at most 1 per second over a 600-step run with many events; hit, wave, game over and
  new high score each produce one.
- **SC-A10-405**: The UI tests pass on the iOS 27 phone simulator; every control has a label.
- **SC-A10-406**: The nine standard scenarios and the fixtures pass on iOS 27; each package test finishes in under 10
  seconds.

## Assumptions

- Reach values, the run number source, the file name and announcement wording are set in clarification.
- Glow caps per quality tier and balance come in A10-P05; the device campaign measures performance and runs the system
  accessibility audits.

## Out of Scope

- Online or shared leaderboards, player names, dates or any personal data in the table, achievements, controller input.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 04 (touch steering with configurable sensitivity) — Phase 04 MVP | FR-A10-401, 402; story 1 |
| Phase 04 regression fixture "high score not corrupted by abrupt termination"; manual §11 fixture 4 | FR-A10-411; story 2 |
| v0.1 feature 03 (flows with local scores) | FR-A10-410–413; story 2 |
| Manual §6 `HighScore(boardVersion, score, achievedAt)`, `HighScoreStore` | FR-A10-410, 411 |
| Constitution A10 Accessibility | FR-A10-402, 420–422; story 3 |
| Contract gaps G-STEERINPUT, G-HIGHSCORES | FR-A10-401, 402, 410–413 |

## Negative Requirements

- No network, accounts, online leaderboards or personal data (no names, no dates, no device identifiers) in the table;
  no permission; no claims of skill, reflex, cognitive or health benefits; no second renderer or context; no ProjectM
  code.
