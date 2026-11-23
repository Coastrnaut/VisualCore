# Feature Specification: R02-G10-06 — Backwards Aurora: polish and accessibility

**Feature Branch**: `396-backwards-aurora-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G10-06 (migration ledger, game feature of experience R02-G10) · ID namespace FR-R02G1006-###,
SC-R02G1006-###, T-R02G1006-###

**Input**: User description: the archived R02-G10-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Backwards Aurora, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/396-backwards-aurora-polish-and-accessiblity`; FR-R02G1006-###,
  SC-R02G1006-###, T-R02G1006-###.
- **Packaging (ADR-0009):** polish and accessibility live in the experience `r02-g10.backwards-aurora` (a registered
  candidate since R02-G10-03) inside the one app; free.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. **Device-only items:** sound,
  haptics and VoiceOver on D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only
  items:** none.
- **Shared features used:** R02-F26 (input and accessibility contract), the shared feedback route (announcements and
  haptics) and the ambient loop player, and the kernel, content, adapter, renderer, gestures and teaching of
  R02-G10-01 … 05.
- **Model:** feature 386 (Nocturne Garden's polish and accessibility) for announcements, haptics, fades, sound and the
  panel's layout.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
386's answers where the games agree. Facts checked in code (read-only, 2026-11-23): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` (1 … 6 partials, a bounded loop length) are those
feature 386 used; Backwards Aurora's shimmer moves at 1.6 rad/s (about 0.25 cycles per second at a point) and its pulse
beads travel 0.12 units of the section per second with at most 2 per unit (at most 0.24 beads per second past a point),
both still under Reduce Motion (time 0); its glow limit is 0.5 under Reduce Flashing (1.5 otherwise); the won lift
(0.35) and the tear cross appear at once when the play is won or tears; the freeze preview ribbon appears at alpha 0.6
after a 0.5 s hold; kink crosses follow the wave after each reversal; the adapter's refusal codes are `r02-g10.action`,
`noop`, `stage`, `stale`, `malformed`, `locked`, `date` and `not-whole`; the presenter shows refusals as "That change
was refused: <code>" and logs their codes; samples are named "sample at position k: height h" and checkpoints
"checkpoint c at position k: height h, target g, matched".

- Q: What exactly is announced, and with which kind? → A: after an accepted reversal (`state`): "Reversed samples i to
  j." followed by " Checkpoints matched k of n; worst bend w of limit L. m reversals left." ("1 reversal left"); undo
  and redo: "Undone." / "Redone." followed by the same measure; a win (`outcome`): "Every checkpoint matches and every
  bend is within the limit. Level won with m reversals made, k of 3 stars." (without the stars in practice); a failure
  (`outcome`): the failure explanation of feature 395; a level or mode change (`level`): "Level n, band b, <mode>." with
  the tutorial instruction when shown; a refusal (`rejection`) in words: `r02-g10.locked` "That level is not open yet.",
  `r02-g10.date` "That date cannot be used.", `r02-g10.action` "That section cannot be reversed here.", `r02-g10.noop`
  "That section reads the same both ways; reversing it changes nothing.", `r02-g10.stage` "The level has ended.",
  `r02-g10.not-whole` "That value must be a whole number.", any other code "That reversal was refused." A revealed hint
  is announced (`state`) with its text. Changes of the section's ends and the freeze preview are not announced (the
  adjustable ends speak their own values; the preview is described in the panel). Texts are a pure function of the old
  and new core (and the refusal code), so tests compare them exactly; the panel shows the same refusal text. Impact:
  FR-R02G1006-002; SC-R02G1006-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted reversal, undo or redo; `success`
  for a win; `warning` for a failure; `error` for a refusal; changes of the section's ends, level changes and previews
  play none. The shared planners' intervals apply; when one reversal both changes the wave and ends the play (the
  winning reversal, a tear or the last reversal of the budget), only the outcome is planned, so an outcome is never
  dropped behind a selection haptic. Impact: FR-R02G1006-003; SC-R02G1006-002.
- Q: How are fades done and measured under Reduce Flashing? → A: the presenter keeps light levels for the aurora's glow
  (0.7 while playing, 1 once won, 0.35 once failed), the won lift (1 once won, else 0), the tear cross (1 while the
  failure is a tear, else 0) and the freeze preview ribbon (1 while a preview shows, else 0), each easing toward its
  target in presentation time (0.15 s normally, 0.45 s under Reduce Flashing, linear; under Reduce Flashing a fade that
  has started finishes before it may turn back). The scene draws the eased levels (the glow gain times the glow level,
  the won lift times its level, the tear cross colour and the preview alpha times theirs); the state and digest never
  see them. Kink crosses change with the player's reversals, as Nocturne Garden's shadow cells do, and are not faded.
  The shimmer (about 0.25 cycles per second) and the pulses (at most 0.24 beads per second past a point) stay below 3
  per second and are still under Reduce Motion. The measure: sampling the drawn levels every 1/60 s through a scripted
  win and adversarial flicker (a tear undone and repeated every frame, retry, level changes, previews held and
  released), no element crosses half its range more than 3 times per second, and every complete one-way fade of more
  than half the range takes at least 0.4 s under Reduce Flashing. Impact: FR-R02G1006-004; SC-R02G1006-003.
- Q: Where does the sound choice live, and what is the recipe? → A: a Sound toggle in the panel, off by default, held by
  the presenter (presentation only; saving it is R02-G10-07). The recipe is a pure function of the wave, the checkpoints
  matched and the stage: a root at 110 Hz times (1, 9/8, 5/4, 4/3) for a worst bend at most the limit, at most twice
  it, at most four times it, or more; one partial per matched checkpoint, up to four, at the root times
  (5/4, 3/2, 2, 5/2)[k − 1], each with the base gain, the root alone when none is matched; an added octave when won and
  halved gains when failed; the loop's length is the longest the shared player accepts at which every partial has a
  whole number of cycles (tested). The presenter rebuilds the loop only when the level opens, a reversal, undo or redo
  changes the matched count, the root step or the stage, or the toggle turns on, never per frame. The loop plays
  exactly while the choice is on, the controls are on screen and the scene is active. Impact: FR-R02G1006-006;
  SC-R02G1006-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the section's
  start and end are accessibility-adjustable elements with their labels and values in words (including the sample's
  height); a summary element reads "m reversals left. Checkpoints matched k of n; worst bend w of limit L, breaking
  limit B. Section i to j, n samples. Checkpoints: <each checkpoint in words>. Level: <the level in words>."; on iPad the
  panel keeps a readable width (at most 520 points). Impact: FR-R02G1006-001, 005; SC-R02G1006-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Backwards Aurora with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the aurora's state (every checkpoint's height against its true height, the worst
bend against the limit and the breaking limit, the chosen section and the reversals left), choose a section's ends,
reverse it, undo and redo, ask for hints, read failures, choose levels and modes, and hear every change and result,
without seeing the aurora. Samples are named by their position and height and checkpoints by number, so no colour or
shape needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the section's start and end are adjustable; every
accepted reversal, undo, redo, refusal, win, failure and level change produces one announcement through the shared route
while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player reverses a section, **Then** the reversal is applied and one
   announcement names the section, the checkpoints matched, the worst bend and the reversals left.
2. **Given** a reversal tears the aurora, **When** the level fails, **Then** the failure explanation is announced as an
   outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get a still aurora, no flashing,
text that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns; an aurora is a glowing, moving
subject.

**Independent Test**: with Reduce Flashing, no drawn element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, the shimmer and the pulses are still; the panel lays out at the largest
accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a section is reversed, the level is won or a reversal tears it, **Then** every
   brightness change is a fade of at least 0.4 s, not a flash.
2. **Given** Reduce Motion, **When** two frames of the same state are drawn at different times, **Then** they are
   identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted reversal gives a light selection haptic; a win a success haptic; a failure a warning; a refused action an
error haptic; all subject to the person's haptics switch. An optional ambient sound, made in code from the wave, the
checkpoints matched and the stage, plays while the experience is on screen and the sound choice is on, and falls silent
off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the ambient recipe is
a pure function of the state it is made from; the loop plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid reversals, undos and redos):** haptics and announcements obey the shared rate limits (a
  burst of announcements posts its newest); an outcome is never lost.
- **A held preview:** the frozen preview is described but not announced; the committed reversal is announced like any
  other.
- **A reversal that ends the level:** only the outcome is announced and felt.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** the loop does not start or stops; the game is unaffected and the sound
  choice stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1006-001**: Every native control (section start and end, reverse, undo, redo, hint, dismiss, retry, level
  picker, modes, next level, reset view, sound) MUST have an accessibility label and value, a summary element MUST read
  the reversals left, the checkpoints against their true heights, the worst bend against the limits and the chosen
  section, and the section's ends MUST be adjustable with VoiceOver.
- **FR-R02G1006-002**: Every accepted reversal, undo and redo MUST be announced with what changed, the checkpoints
  matched, the worst bend and the reversals left (kind `state`); wins and failures (with the explanation) as `outcome`;
  level and mode changes as `level`; refusals in words as `rejection`, through the shared route.
- **FR-R02G1006-003**: Haptics MUST map selection → accepted reversal, undo or redo, success → win, warning → failure,
  error → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G1006-004**: Reduce Flashing MUST cap the glow and turn every brightness change of the aurora's glow, the won
  lift, the tear cross and the freeze preview into fades of at least 0.4 s, with every periodic motion below 3 cycles
  per second; Reduce
  Motion MUST hold the shimmer and the pulses still; neither changes the state or its digest.
- **FR-R02G1006-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G1006-006**: An optional ambient sound MUST be synthesized in code from the worst bend, the checkpoints
  matched and the stage, play only while
  wanted, on screen and active, and never touch audio when off.
- **FR-R02G1006-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the aurora's glow, the won lift, the tear cross and the preview ribbon, eased in presentation time.
- **Ambient recipe**: partials (frequencies, gains) derived from the worst bend, the checkpoints matched and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1006-001**: 100 % of native controls expose a label and value; level 1 is completed using only the
  operations the accessibility actions perform (the ends' increment and decrement and Reverse), with every step
  announced.
- **SC-R02G1006-002**: For scripted sequences of reversals, undos, refusals, wins and failures, the recorded
  announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G1006-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G1006-004**: The ambient recipe is identical for equal states and differs when they differ; the loop plays
  exactly while wanted, on screen and active (state-table test).
- **SC-R02G1006-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.
- **SC-R02G1006-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G10-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G10-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G1006-001, 005 |
| Accessibility (samples by position and height; checkpoints by number) | FR-R02G1006-001, 002, 005 |
| Reduce flashing | FR-R02G1006-004 |
| Audio | FR-R02G1006-006 |
| Haptics | FR-R02G1006-003 |
| No Stage One breakage | FR-R02G1006-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G10-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100; no availability before X-R02-G10.
