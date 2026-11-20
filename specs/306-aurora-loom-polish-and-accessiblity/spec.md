# Feature Specification: R02-G01-06 — Aurora Loom: polish and accessibility

**Feature Branch**: `306-aurora-loom-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G01-06 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0106-###,
SC-R02G0106-###, T-R02G0106-###

**Input**: User description: the archived R02-G01-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Aurora Loom, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/306-aurora-loom-polish-and-accessiblity` (the archived spelling is kept as the
  directory name); FR-R02G0106-###, SC-R02G0106-###, T-R02G0106-###.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free; a registered candidate) in
  `Packages/ExperiencesRound02/AuroraLoom`; no app target, bundle identifier or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** hearing the sound, feeling the haptics and using VoiceOver on real
  hardware are D1/D2/D3 observations after ImplementationLock-100; this feature proves the plans and the wiring on the
  simulator. **Owner-only items:** none.
- **Shared features used:** R02-F26 (the shared feedback route: haptics and VoiceOver announcements through the action
  port, the person's haptics switch, rate limits), the procedural ambient loop of VisualCoreAudio/VisualCoreAudioDSP, the
  shared quality, Reduce Motion and Reduce Flashing contract of the experience host, and R02-G01-01 … 05.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `ExperienceActionPort.haptic(_:)` and `.announce(_:kind:)` route through
`ExperienceFeedback.shared` (the person's haptics switch; `HapticPlanner` drops extras within its interval;
`AnnouncementPlanner` holds a burst and posts its newest after 0.5 s; announcements only while VoiceOver runs);
`AnnouncementKind` has `rejection`, `outcome`, `level`, `state`; `HapticKind` has `selection`, `success`, `warning`,
`error` and impacts; `AmbientLoopPlayer` (VisualCoreAudio, `.ambient` session) plays a fixed `AmbientLoopRecipe` made at
creation; Aurora (A21) holds its sound choice in the presenter, off by default; Aurora Loom's scene caps its glow gain at
0.8 under Reduce Flashing and its gate lights switch at once.

- Q: What exactly is announced, and with which kind? → A: after an accepted move, undo or redo (`state`): "Ribbon r wave
  s. g of 12 gate crossings in harmony. Moves m of n." (phase likewise; undo/redo prefixed "Undone:"/"Redone:"); a win
  (`outcome`): "Harmony. Level won in m moves, k of 3 stars."; a failure (`outcome`): the failure explanation; a level or
  mode change (`level`): "Level n, band b, mode." with the tutorial instruction when shown; a refusal (`rejection`): the
  refusal in words ("That level is not open yet.", "That move was refused: …"). Texts are plain English built by a pure
  function of the old and new core, so tests compare them exactly. Impact: FR-R02G0106-002; SC-R02G0106-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted move, undo or redo; `success` for
  a win; `warning` for a failure; `error` for a refusal; level changes play none. The shared planners' default
  intervals apply (extras dropped); outcomes are never dropped behind a selection because the win or failure is planned
  instead of the move's selection when one action causes both. Impact: FR-R02G0106-003; SC-R02G0106-002.
- Q: How are fades done and measured under Reduce Flashing? → A: the presenter keeps a per-gate and per-ribbon light
  level that eases toward its target in presentation time (0.15 s normally, 0.45 s under Reduce Flashing, linear), plus
  the win glow ramp; under Reduce Flashing a fade that has started finishes before it may turn back, so a flickering
  target cannot hold a level around half; the state and digest never see it. The measure: sampling the drawn light
  levels every 1/60 s through a scripted win and adversarial flicker, no element crosses half its range more than 3 times
  per second, and every complete one-way fade of more than half the range takes at least 0.4 s under Reduce Flashing. Impact: FR-R02G0106-004; SC-R02G0106-003.
- Q: Where does the sound choice live, and when does the ambient recipe change? → A: a Sound toggle in the panel, off by
  default, held by the presenter (presentation only, not state; saving it is R02-G01-07). The recipe is a pure function
  of the three ribbons' current steps and the stage (partials at a pentatonic mapping of each wave step, a brighter
  chord when won, quieter when failed); because the player's recipe is fixed at creation, the presenter rebuilds the loop
  only when the level opens, the play ends or the toggle turns on — not on every move. The loop plays exactly while the
  choice is on, the controls are on screen and the scene is active (the A21 rule). Impact: FR-R02G0106-006;
  SC-R02G0106-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; the steppers become accessibility-adjustable elements labelled "Ribbon r
  wave" or "phase" with the step as value. On iPad the panel keeps a readable width (at most 520 points); the loom view
  is unchanged. Impact: FR-R02G0106-001, 005; SC-R02G0106-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Aurora Loom with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the state, change every ribbon's wave and phase, ask for hints, read failures,
choose levels and modes, and hear every change and result, without seeing the loom.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label, value and adjustable action; every state change, refusal,
win, failure and level change produces one announcement through the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player increments ribbon 2's wave, **Then** the kernel move is applied and one
   announcement names the ribbon, the control, the new step and how many gate crossings are in harmony.
2. **Given** the moves run out, **When** the level fails, **Then** the failure explanation is announced as an outcome.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get a still loom, no flashing, text
that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns.

**Independent Test**: with Reduce Flashing, no drawn element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, the snapshot time stays at 0; the panel lays out at the largest accessibility text
size on iPhone and iPad without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a gate lights or the level is won, **Then** the change is a fade of at least 0.4 s,
   not a flash.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted move gives a light selection haptic; a win a success haptic; a failure a warning; a refused move an error
haptic; all subject to the person's haptics switch. An optional ambient sound, made in code from the ribbons' steps,
plays while the experience is on screen and the sound choice is on, and falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted moves produce the planned haptic kinds through a recording sink; the ambient recipe is a
pure function of the steps and stage; the loop plays only while wanted, on screen and active.

### Edge Cases

- **Many quick moves:** haptics and announcements obey the shared rate limits; a held announcement is posted later,
  never lost for an outcome.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** the loop does not start or stops; the game is unaffected and the sound
  choice stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0106-001**: Every native control (steppers, undo, redo, hint, retry, level picker, modes, tutorial skip,
  reset view) MUST have an accessibility label and value, and the steppers MUST be adjustable with VoiceOver.
- **FR-R02G0106-002**: Every accepted move, undo and redo MUST announce the changed ribbon, control, step and gate
  crossings in harmony (kind `state`); wins and failures (with the explanation) as `outcome`; level and mode changes as
  `level`; refusals as `rejection`, through the shared route.
- **FR-R02G0106-003**: Haptics MUST map selection → accepted move, success → win, warning → failure, error → refused
  move, through the shared route and the person's switch; they never change state.
- **FR-R02G0106-004**: Reduce Flashing MUST cap the glow and turn every brightness change of gates, ribbons and the win
  into fades of at least 0.4 s; Reduce Motion MUST hold the loom still; neither changes the state or its digest.
- **FR-R02G0106-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G0106-006**: An optional ambient sound MUST be synthesized in code from the steps and stage, play only while
  wanted, on screen and active, and never touch audio when off.
- **FR-R02G0106-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Ambient recipe**: partials (frequencies, gains) derived from the steps and stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0106-001**: 100 % of native controls expose a label and value; level 1 is completed using only the operations
  the accessibility actions perform (the steppers' increment and decrement, routed through the presenter's adjust
  operation), with every step announced.
- **SC-R02G0106-002**: For scripted sequences of moves, undos, refusals, wins and failures, the recorded announcements
  and haptics equal the plan exactly (kinds and texts).
- **SC-R02G0106-003**: With Reduce Flashing, the maximum brightness change rate of any drawn element measured over a
  scripted win is at most 3 per second; with Reduce Motion, two frames at different times are identical.
- **SC-R02G0106-004**: The ambient recipe is identical for equal steps and stage and differs when a wave step or the
  stage differs; the loop is rebuilt only when the level opens, the play ends or the toggle turns on, and plays exactly
  while wanted, on screen and active (state-table test).
- **SC-R02G0106-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.

- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G01-05 is unchanged), and sound and
  haptic choices are the app's shared settings. Observability: the presenter keeps a feedback log (announcements and
  haptic kinds with their trigger) for tests and diagnostics, alongside the existing tier log.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G0106-001, 005 |
| Accessibility | FR-R02G0106-001, 002, 005 |
| Reduce flashing | FR-R02G0106-004 |
| Audio | FR-R02G0106-006 |
| Haptics | FR-R02G0106-003 |
| No Stage One breakage | FR-R02G0106-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G01-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100.
