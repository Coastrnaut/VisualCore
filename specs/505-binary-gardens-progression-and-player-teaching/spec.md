# Feature Specification: R02-G21-05 — Binary Gardens: progression and player teaching

**Feature Branch**: `505-binary-gardens-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-05 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2105-###,
SC-R02G2105-###, T-R02G2105-###

**Input**: User description: the archived R02-G21-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Binary Gardens, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/505-binary-gardens-progression-and-player-teaching`; FR-R02G2105-###,
  SC-R02G2105-###, T-R02G2105-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g21.binary-gardens` (a registered
  candidate since R02-G21-03) inside the one app. No app target, bundle identifier, XcodeGen scheme or store listing.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Binary Gardens is free
  (catalog tier `free`), so every level is playable without payment (the shared purchase controller grants it); the
  Round 2 lock and the per-round device campaign; "content count 81" (the 100 certified levels of R02-G21-02 stand);
  the paths `Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore` (the experience lives in
  `Packages/ExperiencesRound02/BinaryGardens`). **Device-only items:** none beyond the device campaign after
  ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression, difficulty
  bands), R02-F26 (accessible text), and the kernel, content, adapter, renderer and gestures of R02-G21-01 … 04.
- **Model:** feature 495 (Mushroom Weather's progression and teaching, itself modelled on feature 485): hints from the
  current state with the certified witness first and a bounded search second, a state-derived tutorial, failure text,
  progress and stars against the certified action count, daily and practice modes and the snapshot migration 1 → 2.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
495's answers where the games agree. Facts checked in code (read-only, 2026-11-27):

- **Kernel (feature 501, with 502's phase step):** a report depends only on the arrangement
  (`BinaryGardensSky.report(level, arrangement:)`: both stars' rings, phases and luminosities and the tilt); the four
  arrangement actions `ring(star:index:)`, `phase(star:step:)`, `luminosity(star:index:)` and `tilt(step:)` each *set*
  one control to a value and spend 1 action; the run (`light.run`) spends none and ends the level, won or failed with
  `frozen(world, tick)`, `scorched(world, tick)`, `unstable(world, window, required)`, `wilted(world, integral, low,
  high)` or `bleached(world, integral, low, high)` (worlds 0-based; ticks are walk ticks 1 … 48 + E), judged in the
  order lethal → window → bloom, worlds ascending, all deterministic; an action out of range, off the phase grid,
  locked, unchanged or breaking the stars' minimum separation is refused `r02-g21.action`, one with no action left
  `r02-g21.budget`; undo works in playing and failed plays, redo in playing, a won play is final; the level gives words
  for stars, worlds and failures (`starDescription`, `worldDescription`, `failureDescription`, `grouped`) and walk ticks
  beyond 48 as "tick 50 (tick 2 of the next cycle)".
- **Content (feature 502):** `BinaryGardensPuzzle(level:).moves(in:)` lists the legal arrangement moves in the fixed
  control order star 1 ring, phase, luminosity, star 2 ring, phase, luminosity, tilt, values ascending, phases on the
  grid, separation breaks excluded; `BinaryGardensSolver.plan` certifies every catalog level by a breadth-first sweep
  (work bound 5,000); the certified witnesses are exactly 1, 2, 3, 3 and 4 arrangement actions by band, then the run,
  and a minimal plan sets each of its controls once (every control it sets differs at the start from the certified
  arrangement; every other control is equal in both); catalog budgets are 8 … 19 (8 … 11, 10 … 13, 12 … 15, 14 … 17,
  16 … 19 by band; the kernel allows 1 … 24); difficulty = band 1 … 5, 20 levels each; levels 1 … 3 carry the tutorial
  flag; catalog levels have at most five adjustable controls with at most 25 one-action moves from any arrangement.
- **Adapter (feature 503) and gestures (504):** `BinaryGardensExperienceCore` prepares level (seed mod 100) + 1, begun
  with its kernel tutorial dismissed (the tutorial is presentation in the presenter's single sentence), keeps the shown
  tick (48 at an opening), the preview, the orbit and the inspected world outside the play, declares `star.ring`,
  `star.phase`, `star.luminosity`, `orbit.tilt`, `light.run`, `play.undo`, `play.redo`, `level.next` (100 wraps to 1)
  and `clock.show`, refuses non-whole values `r02-g21.not-whole` and ticks outside 1 … 48 `r02-g21.tick`, digests
  `"r02-g21.binary-gardens.v1"` (level number and play fingerprint) and snapshots `{level, records}` as schema 1; the
  core may not read a clock. Feature 504 keeps schema 1.
- **Daily multipliers in use** (grep of `dailyMultiplier` in `Packages` and of "× n) mod 100" in `specs`, 2026-11-27):
  17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 and 97. 13 is unused.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play (or `result`
  after a win) and a play in loading, tutorial or paused have no hint; a failed play's hint (also in `result` after a
  failure) is "Undo the last action or retry the level." While playing:
  (a) when the current arrangement already wins (the play's report wins), the hint is "Every world keeps its light:
  run the cycle";
  (b) otherwise, when the current arrangement lies **on the way** to the certified arrangement — each of the seven
  controls holds either its starting value or its certified value — the remaining actions are the certified witness's
  arrangement actions whose control is not yet at its certified value, in the witness's order; when the actions left
  cover them and each, applied in that order from the current arrangement, is a legal move (it keeps the minimum
  separation), the hint is the first of them (so exact hints from a level's start replay its witness, of 1 … 4 actions,
  with no search);
  (c) otherwise a bounded breadth-first search from the current arrangement looks for a winning arrangement reachable
  within min(actions left, 2) actions, an action being any legal move of the puzzle contract in its fixed order (star 1
  ring, phase, luminosity, star 2 ring, phase, luminosity, tilt; values ascending); one action is tried before two;
  every reached arrangement is judged once (the current one never again); work = arrangements judged, bounded at 2,000
  (above any catalog level's two-action space: at most 25 + 25 × 25 = 650); the first action of the first winning
  sequence found is the hint; when none is found within the actions left or the bound would be exceeded, the hint is
  "No way to win was found in the actions left: undo the last action or retry the level."
  Level 1 names the kind of change ("Move a star to another ring", "Shift a star's phase", "Change a star's
  brightness" or "Tilt the orbit plane"); level 2 adds which star and which way ("Move star n outward" or "inward" — a
  higher ring index is outward —; "Shift star n's phase forward" when (target − current) mod 48 is 1 … 24, else "back";
  "Make star n brighter" or "dimmer"; "Tilt the orbit plane more" or "less"); level 3 the exact action ("Move star n to
  ring r (ρ units)", "Shift star n to phase p", "Set star n's luminosity to L", "Set the tilt to t of T steps"), stars
  and rings numbered from 1 (star + 1, index + 1), L the luminosity in units. Hints never change the state, are
  unlimited, do not affect stars and reset to level 1 after any change of the play (any accepted action, undo, redo or
  opening). Impact: FR-R02G2105-002, 009; SC-R02G2105-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), in every
  mode, three instructions in order, each derived from the play's state: (1) `adjust` — "Change a star: drag it along
  its orbit or across its rings, tap a brightness pip or the tilt dial, or use the panel; the gauges show every world's
  light over the whole cycle" — it advances once an arrangement action has been accepted; (2) `balance` — "Keep every
  world's light comfortable for its window, never frozen or scorched for too long, with its total light inside its
  bloom band, then press Run — a hint shows what to change" — it advances once a second arrangement action has been
  accepted in this opening or the level ends; (3) `recover` — "A world that freezes or scorches for too many ticks, has
  too short a comfortable window, or gets too little or too much light in total fails the run: undo and try another
  change" — until the level ends. Any step goes to `done` when the level ends (a won or failed run, or a redo that
  restores a won or failed moment). `tutorial.dismiss` ends it for that opening; undo and redo never move it back;
  `clock.show` never moves it. The step text replaces the presenter's single tutorial sentence. Impact:
  FR-R02G2105-001; SC-R02G2105-001.
- Q: What are the progress and star rules? → A: actions spent for stars count every accepted ring, phase, luminosity
  and tilt record of the play, undone ones included (an undo does not refund effort): 3 stars when at most the certified
  witness's action count (1, 2, 3, 3 or 4 by band), 2 when at most that + 2, else 1. Per level the best (least) actions
  spent of a won campaign or daily play and its stars; a better result replaces a worse one, never the reverse. Level 1
  is open; a campaign win opens the next level (up to 100). `level.select [n]` opens an open level fresh in campaign mode
  and refuses others (`r02-g21.locked`); `level.next` moves to the next open level in campaign mode and is refused
  `r02-g21.locked` when there is none (100 no longer wraps to 1). The five bands of 20 are the certified difficulty
  bands (levels 1 … 20 band 1, … 81 … 100 band 5), shown as "Band b of 5" with the goal ("Win in at most k actions for
  3 stars", k the certified count) and the best result ("Best: s of 3 stars" or "Best: not won yet"). Locked means not
  yet unlocked, never paid for. Impact: FR-R02G2105-004, 006; SC-R02G2105-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 13) mod 100 + 1, negative day counts wrapped into 0 … 99, on the proleptic Gregorian calendar in integer
  arithmetic (13 is coprime with 100, so 100 consecutive days visit every level once, and differs from every other
  round-two game's multiplier); the date reaches the core as `mode.daily [year, month, day]` (years 1 … 9999; an
  impossible date such as 2027-02-29 is refused `r02-g21.date`; a non-whole value `r02-g21.not-whole`). Daily play
  follows campaign rules (a daily win records that level's best result and stars) but opens no level; a daily level
  still locked in the campaign is playable without being opened. `mode.practice` replays the current level fresh with
  the budget raised to the kernel's maximum (24) on a copy of the level; practice results never award stars or open
  levels. `mode.campaign` returns the current level fresh in campaign mode (the frontier level when the current one is
  not open). Choosing a level or a mode starts a fresh play (records dropped, tick 48 shown, tutorial at its first step
  on levels 1 … 3). Impact: FR-R02G2105-005; SC-R02G2105-004.
- Q: Where does progress live, how is it versioned and refused, and how is a failure explained? → A: as feature 495:
  progress and the mode are part of the experience state and its digest (domain `"r02-g21.binary-gardens.v2"`: level,
  play fingerprint, progress, mode); the tutorial step is snapshotted but not digested; the hint level is presentation
  (held by the presenter, its search off the main actor with a generation counter so a stale search never owns the
  hint); the shown tick, the preview, the orbit and the inspected world stay presentation. The snapshot payload becomes
  schema 2 (`{"level", "mode", "progress", "records", "tutorial"}`, sorted keys) with a migration from schema 1: no won
  levels, levels 1 … the restored level open, campaign mode, the tutorial at its first step (`adjust` on levels 1 … 3,
  else `done`); a damaged payload, a level outside 1 … 100, a frontier outside 1 … 100, a result with stars outside
  1 … 3 or actions below 1, or a trace the kernel refuses throws the restore refusal; a newer envelope is refused by the
  engine. New reason codes: `r02-g21.locked` (level not yet open, or no next open level) and `r02-g21.date` (impossible
  date); `r02-g21.not-whole` covers the new controls' values. A failure is explained from the play's failure, worlds
  numbered from 1, ticks in the level's words, numbers grouped as the level groups them:
  frozen — "World n froze at tick t: its light stayed below its lethal floor for more than E ticks in a row." (with
  E = 0: "World n froze at tick t: its light fell below its lethal floor."; "1 tick" in the singular);
  scorched — the same with "scorched" and "above its lethal ceiling" (with E = 0: "World n scorched at tick t: its
  light rose above its lethal ceiling.");
  unstable — "World n kept comfortable light for only w ticks in a row; W were needed." ("1 tick", "1 was needed" in
  the singular; with w = 0 "World n never had comfortable light; W were needed.");
  wilted — "World n wilted: its light over the cycle totalled I, below its bloom band B_lo … B_hi.";
  bleached — "World n bleached: its light over the cycle totalled I, above its bloom band B_lo … B_hi.";
  each followed by one space and "Undo the last action or retry the level." Impact: FR-R02G2105-003, 007;
  SC-R02G2105-003, 005.
- Q: Which existing tests may change? → A: only the assertions this feature deliberately changes, updated in place and
  named in the tasks: the declared control list (five new controls: `level.select`, `mode.daily`, `mode.practice`,
  `mode.campaign`, `tutorial.dismiss`), the schema version 2 and the digest domain v2, and `level.next`'s wrap from 100
  to 1. Every other existing test passes unchanged. Impact: FR-R02G2105-007; SC-R02G2105-006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — change a star by dragging it or tapping a pip
or the dial, watch the gauges, keep every world comfortable long enough and inside its bloom band, then run the cycle
— each advancing when done, and can dismiss them.

**Why this priority**: balancing two moving suns' inverse-square light on several orbiting worlds over a whole cycle
is unfamiliar; without teaching the first levels are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown in that opening and play continues unchanged.
3. **Given** the tutorial is at `balance`, **When** the player undoes the last action, **Then** the instruction stays
   at `balance`.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — which kind of change (a ring, a phase, a
brightness or the tilt), then which star and which way, then the exact value — so that the level can still be won
within the actions left.

**Why this priority**: predicting how a ring, a phase or a tilt changes every world's light at all 48 ticks is hard to
do in the head; a hint keeps the player moving.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only and then runs the cycle,
   **Then** the level is won in the certified number of actions.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.
3. **Given** the current arrangement already wins, **When** a hint is asked, **Then** it says to run the cycle.
4. **Given** a hint at level 2, **When** the player makes any change, **Then** the next hint request starts at level 1.

### User Story 3 - Understand a failure (Priority: P1)

After a run in which a world froze or scorched for too long, kept comfortable light too briefly, or got too little or
too much light in total, the player is told exactly what went wrong — which world, at which tick or with which measure
against which bound — and offered undo or a retry.

**Why this priority**: the failure happens over a whole cycle; without words the player cannot see what to change.

**Independent Test**: every failure explanation names the true world, tick, window and integral values.

**Acceptance Scenarios**:

1. **Given** a run that fails `frozen` at walk tick 50, **When** the result is shown, **Then** the text says the world
   froze at "tick 50 (tick 2 of the next cycle)" and offers undo or retry.
2. **Given** a run that fails `unstable` with a window of 1 tick, **When** the result is shown, **Then** the text uses
   the singular "1 tick".

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars against the certified action count; a daily level comes
from the date; practice relaxes the budget to 24 without affecting progress.

**Why this priority**: pacing across 100 levels in five bands and a reason to return.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

**Acceptance Scenarios**:

1. **Given** only level 1 open, **When** level 3 is selected, **Then** it is refused `r02-g21.locked` and nothing
   changes.
2. **Given** a campaign win of level k in the certified count, **Then** level k records 3 stars and level k + 1 opens.
3. **Given** `mode.daily [2027, 2, 29]`, **Then** it is refused `r02-g21.date`.
4. **Given** a practice win, **Then** no stars are recorded and no level opens.
5. **Given** a schema-1 snapshot of level 7, **When** it is restored, **Then** levels 1 … 7 are open, nothing is won,
   the mode is campaign and the play replays exactly.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when the current arrangement already wins:** it says to run the cycle.
- **A hint off the witness's way:** a control moved to a value that is neither its start nor its certified value, or
  a remaining witness action that would break the separation from here, falls to the bounded search.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless action.
- **A hint with no action left:** the search depth is 0, so only "run the cycle" or the stuck text can result.
- **A hint search that would run long:** bounded by counted work (2,000 arrangements judged); it never stalls a frame.
- **A locked control:** never suggested (only legal moves are tried).
- **A locked level, no next open level or an impossible date:** refused with a named reason (`r02-g21.locked`,
  `r02-g21.date`) and nothing changes.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with levels 1 … its level open and campaign mode.
- **Level 100 won in the campaign:** no further level opens and `level.next` from level 100 is refused
  `r02-g21.locked` (no wrap); every level stays selectable with `level.select`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2105-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it, never moves back on undo or redo and can be dismissed; instructions never block
  or perform actions.
- **FR-R02G2105-002**: A hint MUST be available in three progressive levels, computed from the current state — the
  certified witness's next action while the play is on its way, otherwise a bounded search — so that following the
  exact hints from the start of every certified level, then running the cycle, wins within its budget; from a state
  where no win is found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not
  affect stars and returns to its first level after any change of the play.
- **FR-R02G2105-003**: A failure MUST be explained in accessible text naming its cause (frozen or scorched: the world,
  the walk tick and the tolerance; unstable: the world, its window and the window required; wilted or bleached: the
  world, its integral and its bloom band), with undo and retry offered.
- **FR-R02G2105-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal (the certified action count) and a result (1 … 3 stars by actions spent) per
  level, the best result kept.
- **FR-R02G2105-005**: A daily level MUST be a deterministic function of the local calendar date with the stated
  multiplier 13; a practice mode MUST raise the budget to 24 without affecting progress.
- **FR-R02G2105-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G2105-007**: Progress, the mode and the tutorial step MUST be part of the experience snapshot, schema 2, with
  a migration from schema 1; progress and the mode are digested (domain v2), the tutorial step and every presentation
  value are not; refusals carry named reason codes (`r02-g21.locked`, `r02-g21.date`, `r02-g21.not-whole`, the kernel's
  codes); new public names are documented with `///`; the reference regression passes.
- **FR-R02G2105-008**: The tutorial instruction, the hint and the failure explanation MUST appear as wrapping text in
  the control panel on iPhone and iPad, never over the scene, with a labelled hint button, mode buttons and a picker of
  open levels with their bands and stars, each with an accessibility label, value and identifier; nothing relies on
  colour alone.
- **FR-R02G2105-009**: Hints, tutorial steps, stars, the daily level and the migration MUST be deterministic, integer
  only and free of any clock or random source; the hint search's work MUST be counted and bounded, never timed.
- **FR-R02G2105-010**: Refused progression actions MUST be logged by reason code as the presenter already logs
  refusals, and the panel MUST say why in words.

### Key Entities

- **Tutorial step**: `adjust`, `balance`, `recover`, `done`; the instruction for the current state and its order.
- **Hint**: level 1 … 3, the suggested action (a star's ring, phase or luminosity, or the tilt, with its target value),
  or the run, the stuck text or the undo-or-retry advice.
- **Failure explanation**: the cause (frozen, scorched, unstable, wilted, bleached) with the world, the walk tick or the
  measure and its bound, as text.
- **Progress**: won levels with best actions spent and stars, the open frontier; the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2105-001**: On the three tutorial levels, scripted players following each instruction win, and every
  instruction matches the state it was shown in.
- **SC-R02G2105-002**: For all 100 certified levels, following exact hints from the start and then running the cycle
  wins in the certified action count; for 200 seeded reachable states every exact hint is an action the rules accept,
  and every hint computation judges at most 2,000 arrangements.
- **SC-R02G2105-003**: Every failure explanation in 500 seeded failures, covering all five causes, names the true
  world, tick, window, integral and bounds.
- **SC-R02G2105-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable, and every 100 consecutive days visit each
  level exactly once.
- **SC-R02G2105-005**: A schema-1 snapshot of every level 1 … 100 restores under schema 2 by the migration rules; a
  schema-2 round trip reproduces the digest; every malformed payload is refused.
- **SC-R02G2105-006**: Existing tests pass, apart from the named assertions this feature changes; the reference
  regression passes 7 of 7; each new test finishes under 10 s on the host (asserted locally only, never on CI).

## Assumptions

- Saving progress to disk is R02-G21-07; announcements, haptics and sound are R02-G21-06.
- The kernel's tutorial stage stays dismissed by the adapter; the tutorial steps become the experience's own state.
- The certified plan of each level (the witness's actions without the run) is available to the adapter and the
  presenter from the R02-G21-02 witnesses.
- Observability: refused progression actions are logged by reason code.
- Accessibility: every new text is plain, ordered and available to VoiceOver as panel text; system accessibility audits
  wait for device testing.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G2105-001, 002 |
| Pacing (bands, unlocks) | FR-R02G2105-004 |
| Goals and results | FR-R02G2105-004 |
| Meaningful content (all 100 levels, free) | FR-R02G2105-004, 006 |
| Failure explanation | FR-R02G2105-003 |
| Daily and practice modes | FR-R02G2105-005 |
| Schema migration, error handling | FR-R02G2105-007 |
| Deterministic tests | FR-R02G2105-009; SC-R02G2105-001 … 005 |
| Observability | FR-R02G2105-010 |
| Accessibility | FR-R02G2105-008 |
| Nonfunctional (bounded work, timing, regression) | FR-R02G2105-009; SC-R02G2105-002, 006 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn sky, worlds and gauges are
  unchanged); no advertising, account, network or payment path; no device run before ImplementationLock-100; no
  availability before X-R02-G21; persistence to disk, sound and announcements are later features of R02-G21.
