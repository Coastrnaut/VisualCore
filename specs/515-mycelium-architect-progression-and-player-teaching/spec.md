# Feature Specification: R02-G22-05 — Mycelium Architect: progression and player teaching

**Feature Branch**: `515-mycelium-architect-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G22-05 (migration ledger, game feature of experience R02-G22) · ID namespace FR-R02G2205-###,
SC-R02G2205-###, T-R02G2205-###

**Input**: User description: the archived R02-G22-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Mycelium Architect, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/515-mycelium-architect-progression-and-player-teaching`; FR-R02G2205-###,
  SC-R02G2205-###, T-R02G2205-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g22.mycelium-architect` (a registered
  candidate since R02-G22-03) inside the one app. No app target, bundle identifier, XcodeGen scheme or store listing.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Mycelium Architect is
  free (catalog tier `free`), so every level is playable without payment (the shared purchase controller grants it);
  the Round 2 lock and the per-round device campaign; "content count 84" (the 100 certified levels of R02-G22-02
  stand); the paths `Apps/MyceliumArchitect` and `Packages/GameModules/MyceliumArchitectCore` (the experience lives in
  `Packages/ExperiencesRound02/MyceliumArchitect`). **Device-only items:** none beyond the device campaign after
  ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression, difficulty
  bands), R02-F26 (accessible text), and the kernel, content, adapter, renderer and gestures of R02-G22-01 … 04.
- **Model:** feature 505 (Binary Gardens' progression and teaching): hints from the current state with the certified
  witness first and a bounded search second, a state-derived tutorial, failure text, progress and stars against the
  certified action count, daily and practice modes and the snapshot migration 1 → 2.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
505's answers where the games agree. Facts checked in code (read-only, 2026-11-27):

- **Kernel (feature 511, with 512's sites):** a report depends only on the arrangement
  (`MyceliumArchitectGrowth.report(level, arrangement:)`: placed nutrients, placed blockers and seeds); the five
  arrangement actions `nutrient(cell)`, `blocker(cell)`, `clear(cell)`, `seed(direction)` and `unseed(direction)` each
  spend 1 action; the run (`growth.run`) spends none and ends the level, won or failed with `toxic(pulse, tip, cell)`,
  `starved(pulse, tip, cell, weight, budget)`, `unreached(terminal)` or `overweight(weight, limit)` (tips and terminals
  0-based); a change the change rule refuses (off-board, not empty, not a site, over a placement limit, already seeded,
  seed limit, not seeded, a starting seed) is refused `r02-g22.action`, one with no action left `r02-g22.budget`; undo
  works in playing and failed plays, redo in playing, a won play is final; the level gives words for cells, terminals,
  failures and progress (`cellDescription`, `terminalDescription`, `failureDescription` — "tip 3 grew into toxin at
  (5, 6) on pulse 9" —, `progressDescription`, `grouped`) and directions have compass names ("north-east").
- **Content (feature 512):** `MyceliumArchitectPuzzle(level:).moves(in:)` lists the legal arrangement moves in the
  fixed order nutrient on empty cells ascending (row, column), blocker likewise, clear on placed items ascending, seed
  in ascending direction, unseed likewise, each skipping refused moves (catalog placements only on sites); the
  certified witnesses are exactly 1, 2, 3, 3 and 4 arrangement actions by band, then the run, and are minimal (found by
  a breadth-first search); catalog budgets are 8 … 19 (8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19 by band; the kernel
  allows 1 … 24); difficulty = band 1 … 5, 20 levels each; levels 1 … 3 carry the tutorial flag; catalog levels have at
  most 6 sites, so at most 2 · 6 + 6 + 8 + 8 = 34 one-action moves from any arrangement.
- **Adapter (feature 513) and gestures (514):** `MyceliumArchitectExperienceCore` prepares level (seed mod 100) + 1,
  begun with its kernel tutorial dismissed, keeps the shown pulse, the tool, the preview, the orbit and the inspected
  cell outside the play, declares `cell.nutrient`, `cell.blocker`, `cell.clear`, `root.seed`, `root.unseed`,
  `growth.run`, `play.undo`, `play.redo`, `level.next` (100 wraps to 1) and `growth.show`, refuses non-whole values
  `r02-g22.not-whole` and pulses outside 0 … pulses run `r02-g22.pulse`, digests `"r02-g22.mycelium-architect.v1"`
  (level number and play fingerprint) and snapshots `{level, records}` as schema 1; the core may not read a clock.
  Feature 514 keeps schema 1.
- **Daily multipliers in use** (grep of `dailyMultiplier` in `Packages`, 2026-11-27): 13, 17, 19, 23, 29, 31, 37, 41,
  43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 and 97. 11 is unused and coprime with 100.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play (or `result`
  after a win) and a play in loading, tutorial or paused have no hint; a failed play's hint (also in `result` after a
  failure) is "Undo the last action or retry the level." While playing:
  (a) when the current arrangement already wins (the play's report wins), the hint is "Every terminal is reached
  within the limits: run the growth";
  (b) otherwise, when the current arrangement lies **on the way** to the certified arrangement — for each of placed
  nutrients, placed blockers and seeds, everything in both the start and the certified arrangement is present and
  nothing outside either is present — the remaining actions are the certified witness's arrangement actions not yet
  done (a placement whose item is not yet placed on its cell, a clear whose cell still holds an item, a seed whose
  direction is not yet seeded, an unseed whose direction is still seeded), in the witness's order; when the actions
  left cover them and each, applied in that order from the current arrangement, is a move the rules accept, the hint is
  the first of them (so exact hints from a level's start replay its witness, of 1 … 4 actions, with no search);
  (c) otherwise a bounded breadth-first search from the current arrangement looks for a winning arrangement reachable
  within min(actions left, 2) actions, an action being any legal move of the puzzle contract in its fixed order; one
  action is tried before two; every reached arrangement is judged once (the current one never again); work =
  arrangements judged, bounded at 2,000 (above any catalog level's two-action space: at most 34 + 34 × 34 = 1,190); the
  first action of the first winning sequence found is the hint; when none is found within the actions left or the bound
  would be exceeded, the hint is "No way to win was found in the actions left: undo the last action or retry the
  level."
  Level 1 names the kind of change ("Place a nutrient", "Place a blocker", "Clear a placed nutrient or blocker", "Seed
  a filament from the root" or "Remove a seeded filament"); level 2 adds where: for a cell, its part of the board
  ("in the upper left", "upper right", "lower left" or "lower right" — a column below W / 2 is left, a row below H / 2
  upper, rows counted from the top), for a direction its side ("towards the top" for north, north-east and north-west,
  "towards the bottom" for south, south-east and south-west, "to the east" or "to the west"); level 3 the exact action
  ("Place a nutrient at" / "Place a blocker at" / "Clear" + the level's words for the cell, "Seed a filament to the" /
  "Remove the filament to the" + the compass name). Hints never change the state, are unlimited, do not affect stars
  and reset to level 1 after any change of the play (any accepted action, undo, redo or opening). Impact:
  FR-R02G2205-002, 009; SC-R02G2205-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), in every
  mode, three instructions in order, each derived from the play's state: (1) `place` — "Change the growth: tap an empty
  site to place a nutrient (choose Blocker to turn growth away), or drag from the root to seed a filament; the ghost
  veins show where the growth will go" — it advances once an arrangement action has been accepted; (2) `grow` — "Reach
  every terminal without growing into toxin and keep the network's weight within its limit, then press Run — a hint
  shows what to change" — it advances once a second arrangement action has been accepted in this opening or the level
  ends; (3) `recover` — "A tip that grows into toxin or runs out of nutrient, a terminal left unreached, or a network
  heavier than its limit fails the run: undo and try another change" — until the level ends. Any step goes to `done`
  when the level ends (a won or failed run, or a redo that restores a won or failed moment). `tutorial.dismiss` ends it
  for that opening; undo and redo never move it back; `growth.show` never moves it. The step text replaces the
  presenter's single tutorial sentence. Impact: FR-R02G2205-001; SC-R02G2205-001.
- Q: What are the progress and star rules? → A: actions spent for stars count every accepted nutrient, blocker, clear,
  seed and unseed record of the play, undone ones included (an undo does not refund effort): 3 stars when at most the
  certified witness's action count (1, 2, 3, 3 or 4 by band), 2 when at most that + 2, else 1. Per level the best
  (least) actions spent of a won campaign or daily play and its stars; a better result replaces a worse one, never the
  reverse. Level 1 is open; a campaign win opens the next level (up to 100). `level.select [n]` opens an open level
  fresh in campaign mode and refuses others (`r02-g22.locked`); `level.next` moves to the next open level in campaign
  mode and is refused `r02-g22.locked` when there is none (100 no longer wraps to 1). The five bands of 20 are the
  certified difficulty bands (levels 1 … 20 band 1, … 81 … 100 band 5), shown as "Band b of 5" with the goal ("Win in
  at most k actions for 3 stars", k the certified count) and the best result ("Best: s of 3 stars" or "Best: not won
  yet"). Locked means not yet unlocked, never paid for. Impact: FR-R02G2205-004, 006; SC-R02G2205-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 11) mod 100 + 1, negative day counts wrapped into 0 … 99, on the proleptic Gregorian calendar in integer
  arithmetic (11 is coprime with 100, so 100 consecutive days visit every level once, and differs from every other
  round-two game's multiplier); the date reaches the core as `mode.daily [year, month, day]` (years 1 … 9999; an
  impossible date such as 2027-02-29 is refused `r02-g22.date`; a non-whole value `r02-g22.not-whole`). Daily play
  follows campaign rules (a daily win records that level's best result and stars) but opens no level; a daily level
  still locked in the campaign is playable without being opened. `mode.practice` replays the current level fresh with
  the budget raised to the kernel's maximum (24) on a copy of the level; practice results never award stars or open
  levels. `mode.campaign` returns the current level fresh in campaign mode (the frontier level when the current one is
  not open). Choosing a level or a mode starts a fresh play (records dropped, the pulses run shown, tutorial at its
  first step on levels 1 … 3). Impact: FR-R02G2205-005; SC-R02G2205-004.
- Q: Where does progress live, how is it versioned and refused, how is a failure explained, and which existing tests
  may change? → A: as feature 505: progress and the mode are part of the experience state and its digest (domain
  `"r02-g22.mycelium-architect.v2"`: level, play fingerprint, progress, mode); the tutorial step is snapshotted but not
  digested; the hint level is presentation (held by the presenter, its search off the main actor with a generation
  counter so a stale search never owns the hint); the shown pulse, the tool, the preview, the orbit and the inspected
  cell stay presentation. The snapshot payload becomes schema 2 (`{"level", "mode", "progress", "records",
  "tutorial"}`, sorted keys) with a migration from schema 1: no won levels, levels 1 … the restored level open,
  campaign mode, the tutorial at its first step (`place` on levels 1 … 3, else `done`); a damaged payload, a level
  outside 1 … 100, a frontier outside 1 … 100, a result with stars outside 1 … 3 or actions below 1, or a trace the
  kernel refuses throws the restore refusal; a newer envelope is refused by the engine. New reason codes:
  `r02-g22.locked` (level not yet open, or no next open level) and `r02-g22.date` (impossible date);
  `r02-g22.not-whole` covers the new controls' values. A failure is explained from the play's failure with the level's
  own words (`failureDescription`), its first letter capitalised, then ". " and "Undo the last action or retry the
  level." — toxic: "Tip t grew into toxin at (c, r) on pulse p."; starved: "Tip t ran out of nutrient on pulse p:
  growing to (c, r) would make the branch weight W, above the budget of B."; unreached: "Terminal n at (c, r) was not
  reached."; overweight: "The network's branch weight W is above the limit of L." (tips and terminals numbered from 1,
  numbers grouped as the level groups them). Existing tests change only where this feature deliberately changes them,
  updated in place and named in the tasks: the declared control list (five new controls: `level.select`, `mode.daily`,
  `mode.practice`, `mode.campaign`, `tutorial.dismiss`), the schema version 2 and the digest domain v2, and
  `level.next`'s wrap from 100 to 1; every other existing test passes unchanged. Impact: FR-R02G2205-003, 007;
  SC-R02G2205-003, 005, 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — place a nutrient on a site or seed a filament
from the root, watch the ghost veins, keep the growth away from toxin and inside the weight limit, then run the growth
— each advancing when done, and can dismiss them.

**Why this priority**: steering growth that follows a nutrient gradient, bends with curvature and branches at consumed
nutrients is unfamiliar; without teaching the first levels are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown in that opening and play continues unchanged.
3. **Given** the tutorial is at `grow`, **When** the player undoes the last action, **Then** the instruction stays at
   `grow`.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — which kind of change (a nutrient, a
blocker, a clear, a seed or an unseed), then roughly where, then the exact cell or direction — so that the level can
still be won within the actions left.

**Why this priority**: predicting where a tip will turn after a placement, over many pulses, is hard to do in the head;
a hint keeps the player moving.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only and then runs the growth,
   **Then** the level is won in the certified number of actions.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.
3. **Given** the current arrangement already wins, **When** a hint is asked, **Then** it says to run the growth.
4. **Given** a hint at level 2, **When** the player makes any change, **Then** the next hint request starts at level 1.

### User Story 3 - Understand a failure (Priority: P1)

After a run in which a tip grew into toxin, a tip ran out of nutrient, a terminal was not reached or the network grew
too heavy, the player is told exactly what went wrong — which tip, terminal, cell and pulse, or which weight against
which bound — and offered undo or a retry.

**Why this priority**: the failure happens over many pulses; without words the player cannot see what to change.

**Independent Test**: every failure explanation names the true tip, terminal, cell, pulse, weight and bound.

**Acceptance Scenarios**:

1. **Given** a run that fails `toxic`, **When** the result is shown, **Then** the text names the tip, the toxic cell and
   the pulse and offers undo or retry.
2. **Given** a run that fails `overweight`, **When** the result is shown, **Then** the text names the network's weight
   and the limit, grouped as the level groups numbers.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars against the certified action count; a daily level comes
from the date; practice relaxes the budget to 24 without affecting progress.

**Why this priority**: pacing across 100 levels in five bands and a reason to return.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

**Acceptance Scenarios**:

1. **Given** only level 1 open, **When** level 3 is selected, **Then** it is refused `r02-g22.locked` and nothing
   changes.
2. **Given** a campaign win of level k in the certified count, **Then** level k records 3 stars and level k + 1 opens.
3. **Given** `mode.daily [2027, 2, 29]`, **Then** it is refused `r02-g22.date`.
4. **Given** a practice win, **Then** no stars are recorded and no level opens.
5. **Given** a schema-1 snapshot of level 7, **When** it is restored, **Then** levels 1 … 7 are open, nothing is won,
   the mode is campaign and the play replays exactly.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when the current arrangement already wins:** it says to run the growth.
- **A hint off the witness's way:** a placement or seed that is neither in the start nor in the certified arrangement
  falls to the bounded search.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless action.
- **A hint with no action left:** the search depth is 0, so only "run the growth" or the stuck text can result.
- **A hint search that would run long:** bounded by counted work (2,000 arrangements judged); it never stalls a frame.
- **A refused change (a full count, a starting seed, a non-site cell):** never suggested (only legal moves are tried).
- **A locked level, no next open level or an impossible date:** refused with a named reason (`r02-g22.locked`,
  `r02-g22.date`) and nothing changes.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with levels 1 … its level open and campaign mode.
- **Level 100 won in the campaign:** no further level opens and `level.next` from level 100 is refused
  `r02-g22.locked` (no wrap); every level stays selectable with `level.select`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2205-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it, never moves back on undo or redo and can be dismissed; instructions never block
  or perform actions.
- **FR-R02G2205-002**: A hint MUST be available in three progressive levels, computed from the current state — the
  certified witness's next action while the play is on its way, otherwise a bounded search — so that following the
  exact hints from the start of every certified level, then running the growth, wins within its budget; from a state
  where no win is found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not
  affect stars and returns to its first level after any change of the play.
- **FR-R02G2205-003**: A failure MUST be explained in accessible text naming its cause (toxic: the tip, the cell and the
  pulse; starved: the tip, the cell, the pulse, the weight and the nutrient budget; unreached: the terminal and its
  cell; overweight: the weight and the limit), with undo and retry offered.
- **FR-R02G2205-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal (the certified action count) and a result (1 … 3 stars by actions spent) per
  level, the best result kept.
- **FR-R02G2205-005**: A daily level MUST be a deterministic function of the local calendar date with the stated
  multiplier 11; a practice mode MUST raise the budget to 24 without affecting progress.
- **FR-R02G2205-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G2205-007**: Progress, the mode and the tutorial step MUST be part of the experience snapshot, schema 2, with
  a migration from schema 1; progress and the mode are digested (domain v2), the tutorial step and every presentation
  value are not; refusals carry named reason codes (`r02-g22.locked`, `r02-g22.date`, `r02-g22.not-whole`, the kernel's
  codes); new public names are documented; the reference regression passes.
- **FR-R02G2205-008**: The tutorial instruction, the hint and the failure explanation MUST appear as wrapping text in
  the control panel on iPhone and iPad, never over the scene, with a labelled hint button, mode buttons and a picker of
  open levels with their bands and stars, each with an accessibility label, value and identifier; nothing relies on
  colour alone.
- **FR-R02G2205-009**: Hints, tutorial steps, stars, the daily level and the migration MUST be deterministic, integer
  only and free of any clock or random source; the hint search's work MUST be counted and bounded, never timed.
- **FR-R02G2205-010**: Refused progression actions MUST be logged by reason code as the presenter already logs
  refusals, and the panel MUST say why in words.

### Key Entities

- **Tutorial step**: `place`, `grow`, `recover`, `done`; the instruction for the current state and its order.
- **Hint**: level 1 … 3, the suggested action (a nutrient, blocker or clear on a cell, or a seed or unseed in a
  direction), or the run, the stuck text or the undo-or-retry advice.
- **Failure explanation**: the cause (toxic, starved, unreached, overweight) with the tip or terminal, the cell, the
  pulse or the weight and its bound, as text.
- **Progress**: won levels with best actions spent and stars, the open frontier; the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2205-001**: On the three tutorial levels, scripted players following each instruction win, and every
  instruction matches the state it was shown in.
- **SC-R02G2205-002**: For all 100 certified levels, following exact hints from the start and then running the growth
  wins in the certified action count; for 200 seeded reachable states every exact hint is an action the rules accept,
  and every hint computation judges at most 2,000 arrangements.
- **SC-R02G2205-003**: Every failure explanation in 500 seeded failures, covering all four causes, names the true tip or
  terminal, cell, pulse, weight and bound.
- **SC-R02G2205-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable, and every 100 consecutive days visit each
  level exactly once.
- **SC-R02G2205-005**: A schema-1 snapshot of every level 1 … 100 restores under schema 2 by the migration rules; a
  schema-2 round trip reproduces the digest; every malformed payload is refused.
- **SC-R02G2205-006**: Existing tests pass, apart from the named assertions this feature changes; the reference
  regression passes 7 of 7; each new test finishes under 10 s on the host (asserted locally only, never on CI).

## Assumptions

- Saving progress to disk is R02-G22-07; announcements, haptics and sound are R02-G22-06.
- The kernel's tutorial stage stays dismissed by the adapter; the tutorial steps become the experience's own state.
- The certified plan of each level (the witness's actions without the run) is available to the adapter and the
  presenter from the R02-G22-02 witnesses.
- Observability: refused progression actions are logged by reason code.
- Accessibility: every new text is plain, ordered and available to VoiceOver as panel text; system accessibility audits
  wait for device testing.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G2205-001, 002 |
| Pacing (bands, unlocks) | FR-R02G2205-004 |
| Goals and results | FR-R02G2205-004 |
| Meaningful content (all 100 levels, free) | FR-R02G2205-004, 006 |
| Failure explanation | FR-R02G2205-003 |
| Daily and practice modes | FR-R02G2205-005 |
| Schema migration, error handling | FR-R02G2205-007 |
| Deterministic tests | FR-R02G2205-009; SC-R02G2205-001 … 005 |
| Observability | FR-R02G2205-010 |
| Accessibility | FR-R02G2205-008 |
| Nonfunctional (bounded work, timing, regression) | FR-R02G2205-009; SC-R02G2205-002, 006 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn cave floor, veins and gauges
  are unchanged); no advertising, account, network or payment path; no device run before ImplementationLock-100; no
  availability before X-R02-G22; persistence to disk, sound and announcements are later features of R02-G22.
