# Feature Specification: R02-G06-06 — Chrono Constellator: polish and accessibility

**Feature Branch**: `356-chrono-constellator-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G06-06 (migration ledger, game feature of experience R02-G06) · ID namespace FR-R02G0606-###,
SC-R02G0606-###, T-R02G0606-###

**Input**: User description: the archived R02-G06-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Chrono Constellator, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/356-chrono-constellator-polish-and-accessiblity` (the archived spelling is kept
  as the directory name); FR-R02G0606-###, SC-R02G0606-###, T-R02G0606-###.
- **Packaging (ADR-0009):** experience R02-G06 (`r02-g06.chrono-constellator`, free; a registered candidate) in
  `Packages/ExperiencesRound02/ChronoConstellator`; no app target, bundle identifier or store listing.
- **The shipped kernel:** the timeline game of features 351–355 (stars on loops, start phases and holds, same-tick
  alignment, collisions and the tick limit, 100 certified levels, gestures, hints and progress).
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and the
  "content count 78" milestone figure. **Device-only items:** hearing the sound, feeling the haptics and using VoiceOver
  on real hardware are D1/D2/D3 observations after ImplementationLock-100; this feature proves the plans and the wiring
  on the simulator. **Owner-only items:** none.
- **Shared features used:** R02-F26 (the shared feedback route: haptics and VoiceOver announcements, the person's haptics
  switch, rate limits), the procedural ambient loop of VisualCoreAudio/VisualCoreAudioDSP, the shared quality, Reduce
  Motion and Reduce Flashing contract of the experience host, and R02-G06-01 … 05.
- **Model:** feature 346 (Colorfall Canyons's polish and accessibility), adapted to start phases, holds, the replay, the
  stars and the touch controls of feature 354.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
346's answers where the games agree. Facts checked in code (read-only, 2026-11-21): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` (1 … 6 partials, 4 … 16 s) are those feature 346 used;
Chrono Constellator's ribbon shimmer moves at 0.35 cycles per second with amplitude 0.08, held still under Reduce
Motion (`u_reduceMotion`); its glow limit is 0.5 under Reduce Flashing (1.5 otherwise); a target ring's shade is 1 while
its star stands on it and 0.5 otherwise, and changes at once when a step runs; the collision cross appears at once on a
collision; the adapter's refusal codes are `r02-g06.action`, `budget`, `stage`, `stale`, `malformed`, `locked`, `date`
and `not-whole`; the presenter shows refusals as "That change was refused: <code>" and logs their codes.

- Q: What exactly is announced, and with which kind? → A: after an accepted phase change (`state`): "Star k (shape) starts
  at row r, column c. n edits left." (n = budget − edits in use; "1 edit left"); a hold: "Star k holds from tick s for
  l ticks." with the same suffix; a release: "Star k's hold from tick s removed." with the suffix; a step: "Tick t of T. m
  of N stars on target."; a rewind: "Rewound to tick 0."; undo and redo: "Undone. " / "Redone. " followed by "Tick t of
  T. n edits left."; a star picked in the panel (`state`): "Star k (shape) picked."; a win (`outcome`): "Every star is
  on its target. Level won with e edits, k of 3 stars." (without the stars in practice); a failure (`outcome`): the
  failure explanation of feature 355; a level or mode change (`level`): "Level n, band b, <mode>." with the tutorial
  instruction when shown; a refusal (`rejection`) in words: `r02-g06.locked` "That level is not open yet.",
  `r02-g06.date` "That date cannot be used.", `r02-g06.action` "That change is not allowed here.", `r02-g06.budget` "No
  edits are left.", `r02-g06.stage` "The level has ended.", `r02-g06.not-whole` "That value must be a whole number.",
  any other code "That change was refused." Texts are a pure function of the old and new core (and the refusal code), so
  tests compare them exactly; the panel shows the same refusal text. Impact: FR-R02G0606-002; SC-R02G0606-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted phase change, hold, release, step,
  rewind, undo or redo; `success` for a win; `warning` for a failure; `error` for a refusal; star picks, level changes,
  drag and scrub previews play none. The shared planners' intervals apply; when one action both changes the sky and ends
  the play (a step that wins or fails), only the outcome is planned, so an outcome is never dropped behind a selection
  haptic. Impact: FR-R02G0606-003; SC-R02G0606-002.
- Q: How are fades done and measured under Reduce Flashing? → A: the presenter keeps a light level per target ring (1 lit,
  0.5 unlit), per star node (1 on its target, 0.7 off) and for the win glow and the collision mark (0 or 1), each easing
  toward its target in presentation time (0.15 s normally, 0.45 s under Reduce Flashing, linear); under Reduce Flashing
  a fade that has started finishes before it may turn back. The scene draws the eased levels; the state and digest never
  see them. The ribbon shimmer stays at 0.35 cycles per second (below 3) with amplitude 0.08 and is still under Reduce
  Motion. The measure: sampling the drawn levels every 1/60 s through a scripted win and adversarial flicker (a phase
  changed and undone every frame, steps of 1 tick, rewind, retry), no element crosses half its range more than 3 times
  per second, and every complete one-way fade of more than half the range takes at least 0.4 s under Reduce Flashing.
  Impact: FR-R02G0606-004; SC-R02G0606-003.
- Q: Where does the sound choice live, and what is the recipe? → A: a Sound toggle in the panel, off by default, held by
  the presenter (presentation only; saving it is R02-G06-07). The recipe is a pure function of the stars and the stage:
  a root at 110 Hz and one partial per star on its target at 110 × (3/2, 5/4, 2, 5/3, 9/8)[star], each with the base
  gain, the root alone while no star is on target; a brighter added octave when won and halved gains when failed; a
  12-second loop. The presenter rebuilds the loop only when the level opens, a step, edit, rewind, undo or redo changes
  the stars on target or the stage, or the toggle turns on, never per frame. The loop plays exactly while the choice is
  on, the controls are on screen and the scene is active. Impact: FR-R02G0606-006; SC-R02G0606-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the star picker is
  an accessibility-adjustable element labelled "Star to edit" with the value "Star k (shape), phase p of L"; the phase
  buttons are labelled with the picked star; a summary element reads "Tick t of T. n edits left. Star k (shape): row r,
  column c, start phase p, <holds>, <on or off> its target." for every star; on iPad the panel keeps a readable width (at
  most 520 points). Impact: FR-R02G0606-001, 005; SC-R02G0606-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Chrono Constellator with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the sky's state (each star's shape, cell, start phase, holds and whether it is
on its target, the tick and the edits left), change start phases, add and remove holds, replay, rewind, ask for hints,
read failures, choose levels and modes, and hear every change and result, without seeing the sky. Every star is named by
number and shape, so no colour or position needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the star picker is adjustable; every accepted phase
change, hold, release, step, rewind, undo, redo, refusal, win, failure and level change produces one announcement
through the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player changes a star's start phase, **Then** the change is applied and one
   announcement names the star, its new start cell and the edits left.
2. **Given** two stars collide, **When** the level fails, **Then** the failure explanation is announced as an outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get still ribbons, no flashing, text
that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns.

**Independent Test**: with Reduce Flashing, no drawn element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, the ribbon shimmer is still; the panel lays out at the largest accessibility text
size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a star reaches its target, a collision happens or the level is won, **Then** the
   change is a fade of at least 0.4 s, not a flash.
2. **Given** Reduce Motion, **When** two frames of the same state are drawn at different times, **Then** they are
   identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted edit or replay step gives a light selection haptic; a win a success haptic; a failure a warning; a refused
action an error haptic; all subject to the person's haptics switch. An optional ambient sound, made in code from the
stars on target and the stage, plays while the experience is on screen and the sound choice is on, and falls silent off
screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the ambient recipe is a
pure function of the stars on target and the stage; the loop plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid steps or phase presses):** haptics and announcements obey the shared rate limits (a burst
  of announcements posts its newest); an outcome is never lost.
- **A drag or scrub in progress:** the candidate cell or tick is described but not announced; the released action is
  announced like any other.
- **A step that ends the level:** only the outcome is announced and felt.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** the loop does not start or stops; the game is unaffected and the sound
  choice stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0606-001**: Every native control (star picker, phase − and +, add and remove hold, step 1, step 10, run,
  rewind, undo, redo, hint, dismiss, retry, level picker, modes, next level, reset view, sound) MUST have an accessibility
  label and value, a summary element MUST read the tick, the edits left and each star's shape, cell, start phase, holds
  and target state, and the star picker MUST be adjustable with VoiceOver.
- **FR-R02G0606-002**: Every accepted phase change, hold, release, step, rewind, undo and redo MUST be announced with what
  changed and the edits left (kind `state`); wins and failures (with the explanation) as `outcome`; level and mode
  changes as `level`; refusals in words as `rejection`, through the shared route.
- **FR-R02G0606-003**: Haptics MUST map selection → accepted edit, step, rewind, undo or redo, success → win, warning →
  failure, error → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G0606-004**: Reduce Flashing MUST cap the glow (0.5) and turn every brightness change of the target rings, the
  star nodes and the win and collision marks into fades of at least 0.4 s (eased over 0.45 s), with the ribbon shimmer
  below 3 cycles per second (0.35);
  Reduce Motion MUST hold the shimmer still; neither changes the state or its digest.
- **FR-R02G0606-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G0606-006**: An optional ambient sound MUST be synthesized in code from the stars on target and the stage, play
  only while wanted, on screen and active, and never touch audio when off.
- **FR-R02G0606-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: per target ring, per star node and the win and collision marks, eased in presentation time.
- **Ambient recipe**: partials (frequencies, gains) derived from the stars on target and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0606-001**: 100 % of native controls expose a label and value; level 1 is completed using only the operations
  the accessibility actions perform (the star picker's increment and decrement, phase − and +, run), with every step
  announced.
- **SC-R02G0606-002**: For scripted sequences of phase changes, holds, steps, rewinds, undos, refusals, wins and
  failures, the recorded announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G0606-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G0606-004**: The ambient recipe is identical for equal stars on target and stage and differs when they
  differ; the loop plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G0606-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G06-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G06-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G0606-001, 005 |
| Accessibility (stars named by number and shape) | FR-R02G0606-001, 002, 005 |
| Reduce flashing | FR-R02G0606-004 |
| Audio | FR-R02G0606-006 |
| Haptics | FR-R02G0606-003 |
| No Stage One breakage | FR-R02G0606-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G06-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100; no availability before X-R02-G06.
