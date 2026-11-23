# Feature Specification: R02-G12-06 — Harmonic Bridges: polish and accessibility

**Feature Branch**: `416-harmonic-bridges-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G12-06 (migration ledger, game feature of experience R02-G12) · ID namespace FR-R02G1206-###,
SC-R02G1206-###, T-R02G1206-###

**Input**: User description: the archived R02-G12-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Harmonic Bridges, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/416-harmonic-bridges-polish-and-accessiblity` (the archived spelling of the
  directory is kept); FR-R02G1206-###, SC-R02G1206-###, T-R02G1206-###.
- **Packaging (ADR-0009):** polish and accessibility live in the experience `r02-g12.harmonic-bridges` (a registered
  candidate since R02-G12-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and "content count 82" (the 100 certified
  levels stand). **Device-only items:** sound, haptics and VoiceOver on D1/D2/D3, recorded as `{device}` items for after
  ImplementationLock-100. **Owner-only items:** none.
- **Carried in:** the audible audition of a plucked string, deferred from R02-G12-04.
- **Shared features used:** R02-F26 (input and accessibility contract, shared feedback route), the shared ambient loop
  player, and the kernel, content, adapter, renderer, gestures and teaching of R02-G12-01 … 05.
- **Model:** feature 406 (Echo Cartographer's polish and accessibility).

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
406's answers where the games agree. Facts checked in code (read-only, 2026-11-23): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` are those feature 406 used; Harmonic Bridges' strings
swing with the presentation wave and level-0 adds two wave shells per resonating string, the shown step cycles every
1.2 s, and the won lift reaches membranes and glow rings through a per-vertex won flag that switches at once when the
level is won; a test always ends the level (won or broken); the adapter's refusal codes are `r02-g12.action`, `noop`,
`stage`, `stale`, `level`, `malformed`, `locked`, `date` and `not-whole` (reported by the engine as `action.rule.<code>`),
which the panel words through `HarmonicBridgesMirror.refusalText`; the level words strings "string i, island a to island
b, peg p" (", locked") and progress "step 0: 2 bridges, goal reached; …; 3 actions left".

- Q: What exactly is announced, and with which kind? → A: after an accepted action (`state`), the change then the
  progress: a tuning "String i tuned to peg p."; undo and redo "Undone." / "Redone."; each followed by " The start
  reaches the goal in k of n steps, a actions left."; a win (`outcome`): "The crossing holds in every step. Level won
  spending a actions, k of 3 stars." (without the stars in practice); a failure (`outcome`): the failure explanation of
  feature 415; a level or mode change (`level`): "Level n, band b, <mode>." with the tutorial instruction when shown; a
  refusal (`rejection`) in words: `r02-g12.locked` "That level is not open yet.", `r02-g12.date` "That date cannot be
  used.", `r02-g12.action` "That string cannot be tuned to that peg.", `r02-g12.noop` "That string is already at that
  peg.", `r02-g12.stage` "The level has ended.", `r02-g12.not-whole` "That value must be a whole number.", any other code
  "That action was refused." (the engine's `action.rule.` prefix read as the bare code). A revealed hint is announced
  (`state`) with its text. Choosing a string, previewing a peg and orbit are not announced. Texts are a pure function of
  the old and new core (and the refusal code), so tests compare them exactly; the panel shows the same refusal text.
  Impact: FR-R02G1206-002; SC-R02G1206-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted tuning, undo or redo; `success`
  for a win; `warning` for a failure; `error` for a refusal; choosing, previewing, orbit and level changes play none. A
  test always ends the level, so it plays only its outcome; a tuning that spends the last action without a win plays
  only the warning. The shared planners' intervals apply. Impact: FR-R02G1206-003; SC-R02G1206-002.
- Q: How are fades done and measured under Reduce Flashing? → A: the presenter keeps light levels for the glow (0.7
  while playing, 1 once won, 0.35 once failed) and the won brightening (1 once won, else 0), each easing toward its
  target in presentation time (0.15 s normally, 0.45 s under Reduce Flashing, linear; under Reduce Flashing a fade that
  has started finishes before it may turn back); the scene draws the eased levels (the glow gain times the glow level,
  and the won lift scaled by its level through a uniform, so the per-vertex won flag no longer switches the brightness
  at once); the state and digest never see them. The step cycle changes which membranes are drawn every 1.2 s, so under
  Reduce Flashing the shown step is held (step 0, or the broken step) exactly as under Reduce Motion, the strings are at
  rest and no wave shell is drawn; pegs, marks and membranes change only with the player's actions and are not faded.
  The measure: sampling the drawn levels every 1/60 s through a scripted win and adversarial flicker (a tuning undone and
  redone every frame, retry, level changes), no element crosses half its range more than 3 times per second, and every
  complete one-way fade of more than half the range takes at least 0.4 s under Reduce Flashing; with Reduce Flashing no
  wave shell is drawn in any frame. Impact: FR-R02G1206-004; SC-R02G1206-003.
- Q: Where does the sound choice live, and what are the audition and ambient recipes? → A: a Sound toggle in the panel,
  off by default, held by the presenter (presentation only; saving it is R02-G12-07). The audition of a plucked string
  is a pure function of its peg and its resonant modes and tone strengths in the shown step: a fundamental of
  110 Hz × 2^((peg − 1) / 12); one partial per resonant mode n with tone strength w at the fundamental × n and gain
  0.04 × w; a string that sings no mode gets the fundamental alone at gain 0.02 (the muted pluck); 0.6 s with a linear
  decay to silence; played once per pluck, a new pluck replacing the last. The ambient recipe is a pure function of the
  actions left as a share of the budget, the steps in which the start reaches the goal and the stage: a root at 110 Hz
  times (1, 9/8, 5/4, 4/3) for more than three quarters of the actions left, more than half, more than a quarter, or
  less; one partial per step reached, up to four, at the root times (5/4, 3/2, 2, 5/2)[k − 1], each with the base gain,
  the root alone when none is reached; an added octave when won and halved gains when failed; the loop's length is the
  longest the shared player accepts at which every partial has a whole number of cycles (tested). The presenter rebuilds
  the loop only when the level opens, an action, undo or redo changes the steps reached, the root step or the stage, or
  the toggle turns on, never per frame. Sound plays exactly while the choice is on, the controls are on screen and the
  scene is active. Impact: FR-R02G1206-006; SC-R02G1206-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the chosen string
  and peg are accessibility-adjustable elements with their labels and values in words (the string as the level words it,
  with its current peg and lock); a summary element reads "a actions left. The start reaches the goal in k of n steps.
  Step s shows b bridges. Chosen: <the string in words>, tune to peg p. Level: <the level in words>."; on iPad the panel
  keeps a readable width (at most 520 points). Impact: FR-R02G1206-001, 005; SC-R02G1206-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Harmonic Bridges with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the level's state (the islands and strings, each string's peg and lock, which
strings are bridges in each step, whether the start reaches the goal in each step, the actions left), choose a string
and a peg, tune, test, undo and redo, ask for hints, read failures, choose levels and modes, and hear every change and
result, without seeing the bridges. Strings are named by number, their islands and their peg, so no colour or shape needs
to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the chosen string and peg are adjustable; every
accepted tuning, test, undo, redo, refusal, win, failure and level change produces one announcement through the shared
route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player tunes a string, **Then** it is applied and one announcement names the
   string, its new peg, the steps the start now reaches the goal in and the actions left.
2. **Given** a test breaks, **When** the level fails, **Then** the failure explanation is announced as an outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get still strings, no flashing, text
that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns; swinging strings, expanding wave
shells and brightening bridges are moving, bright subjects.

**Independent Test**: with Reduce Flashing, no faded element changes brightness more than three times a second, no wave
shell is drawn and the glow stays capped; with Reduce Motion, the strings are at rest and the shown step is held; the
panel lays out at the largest accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a string is tuned, a step changes, the level is won or it fails, **Then** no wave
   shell is drawn and every change of the glow, the bridges' brightness and the won brightening is a fade of at least
   0.4 s, not a flash (what the player's action changes — pegs, marks, membranes — appears with the action).
2. **Given** Reduce Motion or Reduce Flashing, **When** two frames of the same state are drawn at different times
   (after any fade has finished), **Then** they are identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted tuning or test gives a light selection haptic; a win a success haptic; a failure a warning; a refused
action an error haptic; all subject to the person's haptics switch. Plucking a string plays a short tone made in code from
that string's resonant modes in the shown step (the audition), and an optional ambient sound, made in code from the
steps bridged, the actions left and the stage, plays while the experience is on screen and the sound choice is on, and
falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the audition and
ambient recipes are pure functions of the state they are made from; sound plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid tunings, undos and redos):** haptics and announcements obey the shared rate limits (a
  burst of announcements posts its newest); an outcome is never lost.
- **An action that ends the level:** only the outcome is announced and felt.
- **Choosing a string, previewing a peg and orbit:** not announced (the adjustable string and peg speak their own
  values); a pluck plays its audition only when the sound choice is on.
- **A string that sings no mode in the shown step:** its audition is a short muted pluck, never silence that looks like
  a fault.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** no sound starts or it stops; the game is unaffected and the sound choice
  stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1206-001**: Every native control (string and peg, tune, test, undo, redo, hint, dismiss, retry, level picker,
  modes, next level, reset view, sound) MUST have an accessibility label and value, a summary element MUST read the
  actions left, the steps the start reaches the goal in, the bridges of the shown step and the chosen string and peg,
  and the chosen string and peg MUST be adjustable with VoiceOver.
- **FR-R02G1206-002**: Every accepted tuning, test, undo and redo MUST be announced with what changed and the actions
  left (kind `state`); wins and failures (with the explanation) as `outcome`; level and mode changes as `level`;
  refusals in words as `rejection`, through the shared route.
- **FR-R02G1206-003**: Haptics MUST map selection → accepted tuning, test, undo or redo, success → win, warning →
  failure, error → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G1206-004**: Reduce Flashing MUST cap the glow, turn every brightness change of the glow, the bridges and the
  won brightening into fades of at least 0.4 s and draw no wave shells, with every periodic motion below 3 cycles per
  second; Reduce Motion MUST hold the strings at rest and the shown step; neither changes the state or its digest.
- **FR-R02G1206-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G1206-006**: A plucked string's audition and an optional ambient sound MUST be synthesized in code — the
  audition from the plucked string's resonant modes and tone strengths in the shown step, the ambient sound from the
  steps bridged, the actions left and the stage — play only while wanted, on screen and active, and never touch audio
  when off.
- **FR-R02G1206-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the glow, the bridges' brightness and the won brightening, eased in presentation time.
- **Audition recipe**: partials (frequencies, gains, decay) derived from a string's resonant modes and tone strengths.
- **Ambient recipe**: partials (frequencies, gains) derived from the steps bridged, the actions left and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1206-001**: 100 % of native controls expose a label and value; level 1 is completed using only the
  operations the accessibility actions perform (the string and peg increment and decrement, Tune and Test), with every
  step announced.
- **SC-R02G1206-002**: For scripted sequences of tunings, tests, undos, refusals, wins and failures, the recorded
  announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G1206-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G1206-004**: The audition and ambient recipes are identical for equal states and differ when they differ; sound
  plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G1206-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.
- **SC-R02G1206-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G12-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G12-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log and the refusal
  log.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G1206-001, 005 |
| Accessibility (strings by number, islands and peg) | FR-R02G1206-001, 002, 005 |
| Reduce flashing | FR-R02G1206-004 |
| Audio (audition and ambient sound) | FR-R02G1206-006 |
| Haptics | FR-R02G1206-003 |
| No Stage One breakage | FR-R02G1206-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G12-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100; no availability before X-R02-G12.
