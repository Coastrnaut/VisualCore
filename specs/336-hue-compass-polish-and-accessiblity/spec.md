# Feature Specification: R02-G04-06 — Hue Compass: polish and accessibility

**Feature Branch**: `336-hue-compass-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G04-06 (migration ledger, game feature of experience R02-G04) · ID namespace FR-R02G0406-###,
SC-R02G0406-###, T-R02G0406-###

**Input**: User description: the archived R02-G04-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Hue Compass, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/336-hue-compass-polish-and-accessiblity` (the archived spelling is kept as the
  directory name); FR-R02G0406-###, SC-R02G0406-###, T-R02G0406-###.
- **Packaging (ADR-0009):** experience R02-G04 (`r02-g04.hue-compass`, free; a registered candidate) in
  `Packages/ExperiencesRound02/HueCompass`; no app target, bundle identifier or store listing.
- **The shipped kernel:** the integer compass wheel of features 331–335 (96 bearings, 24 hue bands, clues of hue gap and
  fog depth, probes and a selection that spend units, 100 certified levels), not the source's 76 levels.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** hearing the sound, feeling the haptics and using VoiceOver on real
  hardware are D1/D2/D3 observations after ImplementationLock-100; this feature proves the plans and the wiring on the
  simulator. **Owner-only items:** none.
- **Shared features used:** R02-F26 (the shared feedback route: haptics and VoiceOver announcements, the person's haptics
  switch, rate limits), the procedural ambient loop of VisualCoreAudio/VisualCoreAudioDSP, the shared quality, Reduce
  Motion and Reduce Flashing contract of the experience host, and R02-G04-01 … 05.
- **Model:** feature 326 (Wave Knot Keeper), adapted to the compass's bearing, probes, clues, selection, the fog drift and
  the touch controls of feature 334.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
326's answers where the games agree. Facts checked in code (read-only, 2026-11-21): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` (1 … 6 partials, 4 … 16 s) are those feature 326
used; Hue Compass's fog drift is 0.01 sin(2π (0.1 Hz · t + phase)) in z, held at t = 0 under Reduce Motion; its glow gain
is capped at 0.5 under Reduce Flashing (2.0 otherwise); probe marks, the selection mark and the target ring appear at
once; the panel has four turn buttons (−4, −1, +1, +4), a band stepper, Probe, Select, Undo, Redo, Hint, the mode and
level controls and Reset view; the presenter has no feedback route yet (refusals only show "That change was refused:
<code>").

- Q: What exactly is announced, and with which kind? → A: after an accepted turn (`state`): "Bearing b of 96, band h.
  Units s of a." (b is 0 … 95, h the band shown 1 … 24); after a probe (`state`): "Probe at bearing b: hue gap g bands,
  fog depth d. Units s of a." ("band" singular for g = 1); undo and redo prefix "Undone: " / "Redone: " to the turn
  text; a band pick (`state`): "Band h picked."; a win (`outcome`): "The bearing and band match. Level won with s units,
  k of 3 stars." (no stars in practice); a failure (`outcome`): the failure explanation of feature 335; a level or mode
  change (`level`): "Level n, band b, <mode>." with the tutorial instruction when shown; a refusal (`rejection`) in
  words: `r02-g04.locked` "That level is not open yet.", `r02-g04.date` "That date cannot be used.", `r02-g04.action`
  "That action is not allowed here.", `r02-g04.allowance` "No units are left.", `r02-g04.stage` "The level has ended.",
  `r02-g04.not-whole` "That value must be a whole number.", any other code "That change was refused." Texts are a pure
  function of the old and new core (and the refusal code), so tests compare them exactly; the panel shows the same
  refusal text. Impact: FR-R02G0406-002; SC-R02G0406-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted turn, probe, undo or redo;
  `success` for a win; `warning` for a failure; `error` for a refusal; band picks, level changes and swipe previews play
  none. The shared planners' intervals apply; when one action both records a clue and ends the play (a probe that spends
  the last unit, or a selection), only the outcome is planned, so an outcome is never dropped behind a selection haptic.
  Impact: FR-R02G0406-003; SC-R02G0406-002.
- Q: How are fades done and measured under Reduce Flashing? → A: the presenter keeps a light level per probe mark (keyed
  by its bearing: 0 absent, 1 present), the selection mark, the target ring and the win glow (0 or 1), each easing toward
  its target in presentation time (0.15 s normally, 0.45 s under Reduce Flashing, linear); under Reduce Flashing a fade
  that has started finishes before it may turn back. The scene draws the eased levels; the state and digest never see
  them. The fog drift stays at 0.1 Hz (below 3 per second) and is still under Reduce Motion. The measure: sampling the
  drawn levels every 1/60 s through a scripted win and adversarial flicker (a turn and its undo every frame, a retry and
  replay), no element crosses half its range more than 3 times per second, and every complete one-way fade of more than
  half the range takes at least 0.4 s under Reduce Flashing. Impact: FR-R02G0406-004; SC-R02G0406-003.
- Q: Where does the sound choice live, and what is the recipe? → A: a Sound toggle in the panel, off by default, held by
  the presenter (presentation only; saving it is R02-G04-07). The recipe is a pure function of the last clue and the
  stage: a root at 110 Hz, a partial at 110 Hz × (1 + g / 12) for the last clue's hue gap g (in unison with the root when g = 0 or no clue yet), a soft fifth
  above the root, gains shaped by the fog depth d (1.0 − 0.4 · min(d, 90) / 90 of a base gain), a brighter added octave
  when won and halved gains when failed; an 8-second loop. The presenter rebuilds the loop only when the level opens, a
  clue is recorded, the play ends or the toggle turns on, never per frame. The loop plays exactly while the choice is on,
  the controls are on screen and the scene is active. Impact: FR-R02G0406-006; SC-R02G0406-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the band stepper
  is an accessibility-adjustable element labelled "Hue band to select" with the value "band h of 24"; the four turn
  buttons are labelled with their spoken turns ("Turn 4 bearings counter-clockwise" …); a summary element reads "Bearing b, band h. Units
  s of a. Last clue: hue gap g bands, fog depth d." ("No clues yet." in place of the last clue before any probe); on iPad the panel keeps a readable width (at most 520 points). Impact:
  FR-R02G0406-001, 005; SC-R02G0406-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Hue Compass with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the compass's state (the bearing and its band, the clues so far, the units left),
turn the compass, probe, choose a band and select, ask for hints, read failures, choose levels and modes, and hear every
change and result, without seeing the wheel. Every clue is spoken as numbers (hue gap in bands, fog depth), so no colour
needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the band stepper is adjustable; every
accepted turn, probe, selection, undo, redo, refusal, win, failure and level change produces one announcement through
the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player probes, **Then** the probe is applied and one announcement names the
   bearing, the hue gap, the fog depth and the units left.
2. **Given** the selection misses, **When** the level fails, **Then** the failure explanation is announced as an
   outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get still fog, no flashing, text that
grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns.

**Independent Test**: with Reduce Flashing, no drawn element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, the fog drift is still; the panel lays out at the largest accessibility text size
without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a probe mark appears, the selection is made or the level is won, **Then** the
   change is a fade of at least 0.4 s, not a flash.
2. **Given** Reduce Motion, **When** two frames are drawn at different times, **Then** they are identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted turn or probe gives a light selection haptic; a win a success haptic; a failure a warning; a refused action
an error haptic; all subject to the person's haptics switch. An optional ambient sound, made in code from the last clue
and the stage, plays while the experience is on screen and the sound choice is on, and falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the ambient recipe is a
pure function of the last clue and the stage; the loop plays only while wanted, on screen and active.

### Edge Cases

- **Many quick turns (a fast swipe or rapid stepper presses):** haptics and announcements obey the shared rate limits (a
  burst of announcements posts its newest); an outcome is never lost.
- **A swipe in progress:** the ghost needle preview is not announced; the released turn is announced like any other.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** the loop does not start or stops; the game is unaffected and the sound
  choice stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **No clue yet:** the sound uses a neutral recipe; announcements say "No clues yet" where clues are summarised.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0406-001**: Every native control (the four turn buttons, probe, band stepper, select, undo, redo, hint,
  dismiss, retry, level picker, modes, next level, reset view, sound) MUST have an accessibility label and value, a
  summary element MUST read the bearing, band, units and last clue, and the band stepper MUST be adjustable with
  VoiceOver.
- **FR-R02G0406-002**: Every accepted turn, undo and redo MUST announce the bearing and its band and the units left;
  every probe the bearing, hue gap, fog depth and units left (kind `state`); wins and failures (with the explanation) as
  `outcome`; level and mode changes as `level`; refusals as `rejection`, through the shared route.
- **FR-R02G0406-003**: Haptics MUST map selection → accepted turn or probe, success → win, warning → failure, error →
  refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G0406-004**: Reduce Flashing MUST cap the glow and turn every brightness change of probe marks, the selection
  mark, the target ring and the win glow into fades of at least 0.4 s, with the fog drift below 3 per second (0.1 Hz);
  Reduce Motion MUST hold the drift still; neither changes the state or its digest.
- **FR-R02G0406-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G0406-006**: An optional ambient sound MUST be synthesized in code from the last clue and the stage, play only
  while wanted, on screen and active, and never touch audio when off.
- **FR-R02G0406-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: per probe mark, the selection mark, the target ring and the win glow, eased in presentation time.
- **Ambient recipe**: partials (frequencies, gains) derived from the last clue and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0406-001**: 100 % of native controls expose a label and value; level 1 is completed using only the operations
  the accessibility actions perform (turn buttons, probe, the band stepper's increment and decrement, select), with every
  step announced.
- **SC-R02G0406-002**: For scripted sequences of turns, probes, undos, refusals, wins and failures, the recorded
  announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G0406-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames at different times are identical.
- **SC-R02G0406-004**: The ambient recipe is identical for equal clue and stage and differs when the hue gap or the stage
  differ; the loop plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G0406-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G04-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G04-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G0406-001, 005 |
| Accessibility (luminance and numbers independent of hue) | FR-R02G0406-001, 002, 005 |
| Reduce flashing | FR-R02G0406-004 |
| Audio | FR-R02G0406-006 |
| Haptics | FR-R02G0406-003 |
| No Stage One breakage | FR-R02G0406-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G04-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100.
