# Feature Specification: R02-G09-06 — Nocturne Garden: polish and accessibility

**Feature Branch**: `386-nocturne-garden-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G09-06 (migration ledger, game feature of experience R02-G09) · ID namespace FR-R02G0906-###,
SC-R02G0906-###, T-R02G0906-###

**Input**: User description: the archived R02-G09-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Nocturne Garden, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/386-nocturne-garden-polish-and-accessiblity`; FR-R02G0906-###,
  SC-R02G0906-###, T-R02G0906-###.
- **Packaging (ADR-0009):** polish and accessibility live in the experience `r02-g09.nocturne-garden` (a registered
  candidate since R02-G09-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. **Device-only items:** sound,
  haptics and VoiceOver on D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only
  items:** none.
- **Shared features used:** R02-F26 (input and accessibility contract), the shared feedback route
  (announcements and haptics) and the ambient loop player, the kernel, content, adapter, renderer, gestures and teaching
  of R02-G09-01 … 05.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Nocturne Garden with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the garden's state (the target and forbidden regions in words, the planted
blooms by number, kind, cell and size, the sun, the match and the leak against what is needed, and the moves left),
plant, move, resize and remove blooms, set the sun, ask for hints, read failures, choose levels and modes, and hear every
change and result, without seeing the garden. Blooms are named by number, kind, cell and size and regions by their role,
so no colour or position needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the pickers are adjustable; every accepted move, undo,
redo, refusal, win, failure and level change produces one announcement through the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player plants a bloom, **Then** the plant is applied and one announcement
   names the bloom, the match, the leak and the moves left.
2. **Given** a move leaks beyond the allowance, **When** the level fails, **Then** the failure explanation is announced
   as an outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get a still garden, no flashing,
text that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns.

**Independent Test**: with Reduce Flashing, no drawn element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, the mist and the blooms are still; the panel lays out at the largest
accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a bloom is planted, the level is won or a leak fails it, **Then** every
   brightness change is a fade of at least 0.4 s, not a flash.
2. **Given** Reduce Motion, **When** two frames of the same state are drawn at different times, **Then** they are
   identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted move gives a light selection haptic; a win a success haptic; a failure a warning; a refused action an
error haptic; all subject to the person's haptics switch. An optional ambient sound, made in code from the blooms, the
sun and the stage, plays while the experience is on screen and the sound choice is on, and falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the ambient recipe is
a pure function of the blooms, the sun and the stage; the loop plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid plants, undos and redos):** haptics and announcements obey the shared rate limits (a burst
  of announcements posts its newest); an outcome is never lost.
- **A drag in progress:** the preview is described but not announced; the committed move is announced like any other.
- **A move that ends the level:** only the outcome is announced and felt.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** the loop does not start or stops; the game is unaffected and the sound
  choice stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0906-001**: Every native control (pickers, plant, move, resize, remove, sun, undo, redo, hint, dismiss,
  retry, level picker, modes, next level, reset view, sound) MUST have an accessibility label and value, a summary
  element MUST read the moves left, the match and leak against what is needed, the sun, every planted bloom and the
  target and forbidden regions, and the pickers MUST be adjustable with VoiceOver.
- **FR-R02G0906-002**: Every accepted move, undo and redo MUST be announced with what changed, the match, the leak and
  the moves left (kind `state`); wins and failures (with the explanation) as `outcome`; level and mode changes as
  `level`; refusals in words as `rejection`, through the shared route.
- **FR-R02G0906-003**: Haptics MUST map selection → accepted move, undo or redo, success → win, warning → failure, error
  → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G0906-004**: Reduce Flashing MUST cap the glow and turn every brightness change of the blooms' glow, the leak
  crosses and the shadow into fades of at least 0.4 s, with the mist drift below 3 cycles per second; Reduce Motion
  MUST hold the mist and the sway still; neither changes the state or its digest.
- **FR-R02G0906-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G0906-006**: An optional ambient sound MUST be synthesized in code from the blooms, the sun and the stage,
  play only while wanted, on screen and active, and never touch audio when off.
- **FR-R02G0906-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the blooms' glow, the leak crosses and the shadow change, eased in presentation time.
- **Ambient recipe**: partials (frequencies, gains) derived from the blooms, the sun and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0906-001**: 100 % of native controls expose a label and value; level 1 is completed using only the operations
  the accessibility actions perform (the pickers' increment and decrement, plant, set sun), with every step announced.
- **SC-R02G0906-002**: For scripted sequences of moves, undos, refusals, wins and failures, the recorded announcements
  and haptics equal the plan exactly (kinds and texts).
- **SC-R02G0906-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G0906-004**: The ambient recipe is identical for equal blooms, sun and stage and differs when they differ; the
  loop plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G0906-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.
- **SC-R02G0906-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G09-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G09-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G0906-001, 005 |
| Accessibility (blooms named by number, kind, cell and size; regions by role) | FR-R02G0906-001, 002, 005 |
| Reduce flashing | FR-R02G0906-004 |
| Audio | FR-R02G0906-006 |
| Haptics | FR-R02G0906-003 |
| No Stage One breakage | FR-R02G0906-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G09-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100; no availability before X-R02-G09.
