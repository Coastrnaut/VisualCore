# Feature Specification: R02-G03-06 — Wave Knot Keeper: polish and accessibility

**Feature Branch**: `326-wave-knot-keeper-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G03-06 (migration ledger, game feature of experience R02-G03) · ID namespace FR-R02G0306-###,
SC-R02G0306-###, T-R02G0306-###

**Input**: User description: the archived R02-G03-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Wave Knot Keeper, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/326-wave-knot-keeper-polish-and-accessiblity` (the archived spelling is kept as
  the directory name); FR-R02G0306-###, SC-R02G0306-###, T-R02G0306-###.
- **Packaging (ADR-0009):** experience R02-G03 (`r02-g03.wave-knot-keeper`, free; a registered candidate) in
  `Packages/ExperiencesRound02/WaveKnotKeeper`; no app target, bundle identifier or store listing.
- **The shipped kernel:** the integer lattice rope of features 321–325 (unit-step moves of control points, crossing
  gates, the projection summary of crossings and writhe, a tension bound, 100 certified levels), not the source's
  splines, constraint relaxation or 72 levels.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** hearing the sound, feeling the haptics and using VoiceOver on real
  hardware are D1/D2/D3 observations after ImplementationLock-100; this feature proves the plans and the wiring on the
  simulator. **Owner-only items:** none.
- **Shared features used:** R02-F26 (the shared feedback route: haptics and VoiceOver announcements, the person's haptics
  switch, rate limits), the procedural ambient loop of VisualCoreAudio/VisualCoreAudioDSP, the shared quality, Reduce
  Motion and Reduce Flashing contract of the experience host, and R02-G03-01 … 05.
- **Model:** feature 316 (Lissajous Labyrinth), adapted to the rope's points, the six step directions, crossings and
  writhe against the target, the gates, the caustic pulses and the touch controls of feature 324.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Wave Knot Keeper with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the rope's state (crossings and writhe against the target, moves left, the
selected point), choose a point, move it in each of the six directions, ask for hints, read failures, choose levels and
modes, and hear every change and result, without seeing the rope.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the point picker is adjustable; every accepted move,
undo, redo, refusal, win, failure and level change produces one announcement through the shared route while VoiceOver
runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player moves point 3 up, **Then** the kernel move is applied and one
   announcement names the point, the direction, the rope's crossings and writhe against the target and the moves left.
2. **Given** the moves run out, **When** the level fails, **Then** the failure explanation is announced as an outcome.
3. **Given** VoiceOver runs, **When** a move is refused (a strand would cross outside a gate), **Then** the refusal is
   announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get still pulses, no flashing, text
that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns.

**Independent Test**: with Reduce Flashing, no drawn element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, the caustic pulses are still; the panel lays out at the largest accessibility
text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a crossing appears or disappears, the rope matches the target or the level is
   won, **Then** the change is a fade of at least 0.4 s, not a flash.
2. **Given** Reduce Motion, **When** two frames are drawn at different times, **Then** they are identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted move gives a light selection haptic; a win a success haptic; a failure a warning; a refused move an error
haptic; all subject to the person's haptics switch. An optional ambient sound, made in code from the rope's summary,
plays while the experience is on screen and the sound choice is on, and falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted moves produce the planned haptic kinds through a recording sink; the ambient recipe is a
pure function of the summary, target and stage; the loop plays only while wanted, on screen and active.

### Edge Cases

- **Many quick moves (rapid button presses):** haptics and announcements obey the shared rate limits (a burst of
  announcements posts its newest); an outcome is never lost.
- **A drag in progress:** the preview (ghost handle) is not announced; the released move is announced like any other;
  a selection by tap is announced as the selected point.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** the loop does not start or stops; the game is unaffected and the sound
  choice stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.
- **A degenerate projection (two strands overlap in the view):** the announcement says so instead of giving counts.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0306-001**: Every native control (point picker, six direction buttons, undo, redo, hint, dismiss, retry,
  level picker, modes, next level, reset view, sound) MUST have an accessibility label and value, and the point picker
  MUST be adjustable with VoiceOver.
- **FR-R02G0306-002**: Every accepted move, undo and redo MUST announce the point and direction, the crossings and
  writhe against the target and the moves left (kind `state`); wins and failures (with the explanation) as `outcome`;
  level and mode changes as `level`; refusals as `rejection`, through the shared route.
- **FR-R02G0306-003**: Haptics MUST map selection → accepted move, success → win, warning → failure, error → refused
  move, through the shared route and the person's switch; they never change state.
- **FR-R02G0306-004**: Reduce Flashing MUST cap the glow and turn every brightness change of crossing marks, the target
  match and the win into fades of at least 0.4 s, with the caustic pulses slowed below 3 per second; Reduce Motion MUST
  hold the pulses still; neither changes the state or its digest.
- **FR-R02G0306-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G0306-006**: An optional ambient sound MUST be synthesized in code from the rope's summary and the stage,
  play only while wanted, on screen and active, and never touch audio when off.
- **FR-R02G0306-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of a move.
- **Light levels**: per crossing mark, the target match and the win glow, eased in presentation time.
- **Ambient recipe**: partials (frequencies, gains) derived from the summary, target and stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0306-001**: 100 % of native controls expose a label and value; level 1 is completed using only the
  operations the accessibility actions perform (the point picker's increment and decrement and the direction buttons),
  with every step announced.
- **SC-R02G0306-002**: For scripted sequences of moves, undos, refusals, wins and failures, the recorded announcements
  and haptics equal the plan exactly (kinds and texts).
- **SC-R02G0306-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames at different times are identical.
- **SC-R02G0306-004**: The ambient recipe is identical for equal summary, target and stage and differs when the crossings
  or the stage differ; the loop plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G0306-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G03-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G03-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G0306-001, 005 |
| Accessibility | FR-R02G0306-001, 002, 005 |
| Reduce flashing | FR-R02G0306-004 |
| Audio | FR-R02G0306-006 |
| Haptics | FR-R02G0306-003 |
| No Stage One breakage | FR-R02G0306-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G03-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100.
