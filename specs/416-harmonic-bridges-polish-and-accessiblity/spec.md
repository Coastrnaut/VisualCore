# Feature Specification: R02-G12-06 — Harmonic Bridges: polish and accessibility

**Feature Branch**: `416-harmonic-bridges-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

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
2. **Given** Reduce Motion, **When** two frames of the same state are drawn at different times, **Then** they are
   identical.

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
