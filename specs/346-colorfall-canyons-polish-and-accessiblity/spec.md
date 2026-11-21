# Feature Specification: R02-G05-06 — Colorfall Canyons: polish and accessibility

**Feature Branch**: `346-colorfall-canyons-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G05-06 (migration ledger, game feature of experience R02-G05) · ID namespace FR-R02G0506-###,
SC-R02G0506-###, T-R02G0506-###

**Input**: User description: the archived R02-G05-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Colorfall Canyons, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/346-colorfall-canyons-polish-and-accessiblity` (the archived spelling is kept as
  the directory name); FR-R02G0506-###, SC-R02G0506-###, T-R02G0506-###.
- **Packaging (ADR-0009):** experience R02-G05 (`r02-g05.colorfall-canyons`, free; a registered candidate) in
  `Packages/ExperiencesRound02/ColorfallCanyons`; no app target, bundle identifier or store listing.
- **The shipped kernel:** the whole-unit canyon flow of features 341–345 (springs of cyan, coral and yellow, carvable
  cells, valves, basins with colour targets, contamination, overflow and time verdicts, 100 certified levels).
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** hearing the sound, feeling the haptics and using VoiceOver on real
  hardware are D1/D2/D3 observations after ImplementationLock-100; this feature proves the plans and the wiring on the
  simulator. **Owner-only items:** none.
- **Shared features used:** R02-F26 (the shared feedback route: haptics and VoiceOver announcements, the person's haptics
  switch, rate limits), the procedural ambient loop of VisualCoreAudio/VisualCoreAudioDSP, the shared quality, Reduce
  Motion and Reduce Flashing contract of the experience host, and R02-G05-01 … 05.
- **Model:** feature 336 (Hue Compass's polish and accessibility), adapted to carving, valves, the fluid run, the basins
  and the touch controls of feature 344.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
336's answers where the games agree. Facts checked in code (read-only, 2026-11-21): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` (1 … 6 partials, 4 … 16 s) are those feature 336 used;
Colorfall Canyons's flow bands move at 0.5 cycles per second (1 on waterfalls) with a band depth of 0.35, held at t = 0
under Reduce Motion; its glow limit is 0.5 under Reduce Flashing (2.0 otherwise); fluid sheet brightness is
0.35 + 0.65 · min(volume, 24) / 24 and changes at once when a step runs, an emitter dims to 0.3 when not flowing; the
kernel's refusal codes are `r02-g05.action`, `budget`, `stage`, `stale`, `malformed`, `locked`, `date` and `not-whole`;
the presenter has no feedback route yet (refusals show "That change was refused: <code>").

- Q: What exactly is announced, and with which kind? → A: after an accepted carve (`state`): "Carved row r, column c. n
  actions left." (n = budget − spent; "1 action left"); a valve: "<Colour> valve open." or "<Colour> valve closed." with
  the same suffix; a step: "Tick t of T. f of m basins filled." (filled = the basin accepts its masses); undo and redo:
  "Undone. " / "Redone. " followed by "Tick t of T. n actions left."; a cell picked in the panel (`state`): "Row r,
  column c picked."; a win (`outcome`): "Every basin is filled. Level won with s actions, k of 3 stars." (without the
  stars in practice); a failure (`outcome`): the failure explanation of feature 345; a level or mode change (`level`):
  "Level n, band b, <mode>." with the tutorial instruction when shown; a refusal (`rejection`) in words:
  `r02-g05.locked` "That level is not open yet.", `r02-g05.date` "That date cannot be used.", `r02-g05.action` "That
  action is not allowed here.", `r02-g05.budget` "No actions are left.", `r02-g05.stage` "The level has ended.",
  `r02-g05.not-whole` "That value must be a whole number.", any other code "That change was refused." Texts are a pure
  function of the old and new core (and the refusal code), so tests compare them exactly; the panel shows the same
  refusal text. Impact: FR-R02G0506-002; SC-R02G0506-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted carve, valve, step, undo or redo;
  `success` for a win; `warning` for a failure; `error` for a refusal; cell picks, level changes and drag highlights play
  none. The shared planners' intervals apply; when one action both changes the canyon and ends the play (a step that
  wins or fails), only the outcome is planned, so an outcome is never dropped behind a selection haptic. Impact:
  FR-R02G0506-003; SC-R02G0506-002.
- Q: How are fades done and measured under Reduce Flashing? → A: the presenter keeps a light level per fluid cell (its
  sheet brightness, 0 when empty), per spring emitter (1 flowing, 0.3 not) and the win glow (0 or 1), each easing toward
  its target in presentation time (0.15 s normally, 0.45 s under Reduce Flashing, linear); under Reduce Flashing a fade
  that has started finishes before it may turn back. The scene draws the eased levels; the state and digest never see
  them. The flow bands stay at 0.5 (1 on waterfalls) cycles per second, below 3, with depth 0.35, and are still under
  Reduce Motion. The measure: sampling the drawn levels every 1/60 s through a scripted win and adversarial flicker (a
  valve toggled and undone every frame, steps of 1 tick, retry), no element crosses half its range more than 3 times per
  second, and every complete one-way fade of more than half the range takes at least 0.4 s under Reduce Flashing.
  Impact: FR-R02G0506-004; SC-R02G0506-003.
- Q: Where does the sound choice live, and what is the recipe? → A: a Sound toggle in the panel, off by default, held by
  the presenter (presentation only; saving it is R02-G05-07). The recipe is a pure function of the basins and the stage:
  a root at 98 Hz, one partial per spring colour with fluid in the basins (cyan 98 × 3/2, coral 98 × 5/4, yellow 98 × 2)
  whose gain is the base gain × (0.3 + 0.7 · that colour's share of all basin mass), the root alone while no basin holds
  fluid; a brighter added octave when won and halved gains when failed; a 10-second loop. The presenter rebuilds the loop only when the level opens, a step,
  carve, valve, undo or redo changes the basins or the stage, or the toggle turns on, never per frame. The loop plays
  exactly while the choice is on, the controls are on screen and the scene is active. Impact: FR-R02G0506-006;
  SC-R02G0506-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the cell picker is
  an accessibility-adjustable element labelled "Cell to carve" with the value "row r, column c"; each valve button is
  labelled "<Colour> valve" with the value "open, n units left", "closed" or "dry"; a summary element reads "Tick t of
  T. n actions left. Basin k: cyan a, coral b, yellow c; target <description>." for every basin; on iPad the panel keeps
  a readable width (at most 520 points). Impact: FR-R02G0506-001, 005; SC-R02G0506-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Colorfall Canyons with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the canyon's state (each basin's colours against its target, each spring's valve
and supply, the tick and the actions left), carve cells, switch valves, run the fluid, ask for hints, read failures,
choose levels and modes, and hear every change and result, without seeing the canyon. Every colour is spoken by name and
amount, so no hue needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the cell picker is adjustable; every accepted carve,
valve, step, undo, redo, refusal, win, failure and level change produces one announcement through the shared route while
VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player carves a cell, **Then** the carve is applied and one announcement names
   the cell and the actions left.
2. **Given** a basin is contaminated, **When** the level fails, **Then** the failure explanation is announced as an
   outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get still flow bands, no flashing,
text that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns.

**Independent Test**: with Reduce Flashing, no drawn element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, the flow bands are still; the panel lays out at the largest accessibility text
size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** fluid reaches a basin, a valve turns or the level is won, **Then** the change is a
   fade of at least 0.4 s, not a flash.
2. **Given** Reduce Motion, **When** two frames of the same state are drawn at different times, **Then** they are
   identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted carve, valve or run gives a light selection haptic; a win a success haptic; a failure a warning; a refused
action an error haptic; all subject to the person's haptics switch. An optional ambient sound, made in code from the
basins' fill and the stage, plays while the experience is on screen and the sound choice is on, and falls silent off
screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the ambient recipe is a
pure function of the basins and the stage; the loop plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid steps or carves):** haptics and announcements obey the shared rate limits (a burst of
  announcements posts its newest); an outcome is never lost.
- **A drag in progress:** the highlighted cell is described but not announced; the released carve is announced like any
  other.
- **A step that ends the level:** only the outcome is announced and felt.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** the loop does not start or stops; the game is unaffected and the sound
  choice stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0506-001**: Every native control (the cell picker and carve, each valve, step 1, step 10, run, undo, redo,
  hint, dismiss, retry, level picker, modes, next level, reset view, sound) MUST have an accessibility label and value, a
  summary element MUST read the tick, the actions left, each spring's valve and each basin's colours against its target,
  and the cell picker MUST be adjustable with VoiceOver.
- **FR-R02G0506-002**: Every accepted carve, valve, step, undo and redo MUST be announced with what changed and the
  actions left (kind `state`); wins and failures (with the explanation) as `outcome`; level and mode changes as `level`;
  refusals in words as `rejection`, through the shared route.
- **FR-R02G0506-003**: Haptics MUST map selection → accepted carve, valve, step, undo or redo, success → win, warning →
  failure, error → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G0506-004**: Reduce Flashing MUST cap the glow and turn every brightness change of the fluid sheets, the spring
  emitters and the win glow into fades of at least 0.4 s, with the flow bands below 3 cycles per second; Reduce Motion
  MUST hold the bands still; neither changes the state or its digest.
- **FR-R02G0506-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G0506-006**: An optional ambient sound MUST be synthesized in code from the basins' fill and the stage, play
  only while wanted, on screen and active, and never touch audio when off.
- **FR-R02G0506-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: per fluid sheet, per spring emitter and the win glow, eased in presentation time.
- **Ambient recipe**: partials (frequencies, gains) derived from the basins' fill and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0506-001**: 100 % of native controls expose a label and value; level 1 is completed using only the operations
  the accessibility actions perform (the cell picker's increment and decrement, carve, valves, run), with every step
  announced.
- **SC-R02G0506-002**: For scripted sequences of carves, valves, steps, undos, refusals, wins and failures, the recorded
  announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G0506-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G0506-004**: The ambient recipe is identical for equal basins and stage and differs when the fill or the stage
  differ; the loop plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G0506-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G05-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G05-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G0506-001, 005 |
| Accessibility (colours named, patterns beside hue) | FR-R02G0506-001, 002, 005 |
| Reduce flashing | FR-R02G0506-004 |
| Audio | FR-R02G0506-006 |
| Haptics | FR-R02G0506-003 |
| No Stage One breakage | FR-R02G0506-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G05-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100; no availability before X-R02-G05.
