# Feature Specification: R02-G20-06 — Mushroom Weather: polish and accessibility

**Feature Branch**: `496-mushroom-weather-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Draft

**Ledger gate**: R02-G20-06 (migration ledger, game feature of experience R02-G20) · ID namespace FR-R02G2006-###,
SC-R02G2006-###, T-R02G2006-###

**Input**: User description: the archived R02-G20-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Mushroom Weather, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/496-mushroom-weather-polish-and-accessiblity` (the archived spelling of the
  directory is kept); FR-R02G2006-###, SC-R02G2006-###, T-R02G2006-###.
- **Packaging (ADR-0009):** polish and accessibility live in the experience `r02-g20.mushroom-weather` (a registered
  candidate since R02-G20-03) inside the one app; no app target, bundle identifier, scheme or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and "content count 76" (the 100
  certified levels stand); entitlement is the shared purchase controller's, tier free. **Device-only items:** sound,
  haptics and VoiceOver on D1/D2/D3, recorded as `{device}` items for after ImplementationLock-100. **Owner-only
  items:** none.
- **Shared features used:** R02-F26 (input and accessibility contract, shared feedback route), the shared ambient loop
  player, and the kernel, content, adapter, renderer, gestures and teaching of R02-G20-01 … 05.
- **Model:** feature 486 (Microscopic Aurora's polish and accessibility), adapted to pods placed on sites, vents and the
  moonlight, the run of the weather, the colonies' bands and the dried, mold and unstable failures.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Mushroom Weather with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the level's state (the pods by slot with their sites, the vents open or closed,
the moonlight level, each colony's humidity against its band at the shown cycle, whether running now would win and why
not, the panel's selected slot and site, the shown cycle, the actions left), place, move and remove pods, open and close
vents, change the moonlight, run the weather, undo and redo, ask for hints, read failures, choose levels and modes, and
hear every change and result, without seeing the forest. Sites, pods, vents, colonies and cells are named by number or
by row and column, so no colour or shape needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the panel's slot, site and moonlight are adjustable;
every accepted pod, vent and moonlight action, run, undo, redo, refusal, win, failure and level change produces one
announcement through the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player places a pod or opens a vent, **Then** it is applied and one
   announcement names the change, the colonies in band and the actions left.
2. **Given** a run fails, **When** the level fails, **Then** the failure explanation is announced as an outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get a still forest, no flashing,
text that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns; glowing caps that light up on a win
and drifting droplets are bright and moving subjects.

**Independent Test**: with Reduce Flashing, no faded element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, two frames of the same state at different times are identical; the panel lays
out at the largest accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** the level is won or fails, **Then** every change of the glow and of the won look
   is a fade of at least 0.4 s, not a flash (what the player's action changes — the pods, the vents, the moonlight, the
   mist, the gauges — appears with the action).
2. **Given** Reduce Motion or Reduce Flashing, **When** two frames of the same state are drawn at different times
   (after any fade has finished), **Then** they are identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted pod, vent or moonlight action, undo or redo gives a light selection haptic; a win a success haptic; a
failure a warning; a refused action an error haptic; all subject to the person's haptics switch. Choosing the panel's
site plays a short tone made in code from that site (the audition), and an optional ambient sound, made in code from the
colonies in band, the moonlight and the stage, plays while the experience is on screen and the sound choice is on, and
falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the audition and
ambient recipes are pure functions of the state they are made from; sound plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid placements, vent toggles, undos and redos):** haptics and announcements obey the shared
  rate limits (a burst of announcements posts its newest); an outcome is never lost.
- **A run, which always ends the level:** only the outcome (win or failure) is announced and felt.
- **Changing the panel's selection, drag previews, the shown cycle and the view:** not announced (the adjustable
  controls speak their own values); changing the selection plays its audition only when the sound choice is on.
- **A selected site that cannot take a pod (another pod holds it, or every slot is used):** its audition is audibly
  different, never silence.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** no sound starts or it stops; the game is unaffected and the sound choice
  stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2006-001**: Every native control (slot, site, place, remove, vent toggles, moonlight, shown cycle, run, undo,
  redo, hint, dismiss, level picker, modes, next level, reset view, sound) MUST have an accessibility label and value, a
  summary element MUST read the actions left, the colonies in band and whether running now would win, the pods, vents
  and moonlight and the selected slot and site, and the panel's slot, site and moonlight MUST be adjustable with
  VoiceOver.
- **FR-R02G2006-002**: Every accepted pod, vent and moonlight action, undo and redo MUST be announced with what changed,
  the colonies in band and the actions left (kind `state`); wins and failures (with the explanation) as `outcome`; level
  and mode changes as `level`; refusals in words as `rejection`, through the shared route.
- **FR-R02G2006-003**: Haptics MUST map selection → accepted pod, vent or moonlight action, undo or redo, success → win,
  warning → failure, error → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G2006-004**: Reduce Flashing MUST cap the glow and turn every brightness change of the glow and of the won
  look into fades of at least 0.4 s, with every periodic motion below 3 cycles per second; Reduce Motion and Reduce
  Flashing MUST keep the forest still between actions (no drifting droplets or motes); neither changes the state or its
  digest.
- **FR-R02G2006-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G2006-006**: A site audition and an optional ambient sound MUST be synthesized in code — the audition from the
  panel's selected site (its position and whether a pod can go there), the ambient sound from the colonies in band, the
  moonlight and the stage — play only while wanted, on screen and active, and never touch audio when off.
- **FR-R02G2006-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the glow and the won look, eased by the frame clock's elapsed time.
- **Audition recipe**: partials (frequencies, gains, decay) derived from the selected site.
- **Ambient recipe**: partials (frequencies, gains) derived from the colonies in band, the moonlight and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2006-001**: 100 % of native controls expose a label and value; level 1 is completed using only the
  operations the accessibility actions perform (the slot, site and moonlight increments and decrements, the vent
  toggles, Place and Run), with every step announced.
- **SC-R02G2006-002**: For scripted sequences of pod, vent and moonlight actions, undos, refusals, wins and failures, the
  recorded announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G2006-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G2006-004**: The audition and ambient recipes are identical for equal states and differ when they differ;
  sound plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G2006-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.
- **SC-R02G2006-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G20-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G20-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log and the refusal
  log.
- Error handling: a refused action changes nothing and is explained in words; an unavailable audio session leaves the
  game silent and playable.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G2006-001, 005 |
| Accessibility (sites, pods, vents, colonies and cells by number; bands in words) | FR-R02G2006-001, 002, 005 |
| Reduce flashing | FR-R02G2006-004 |
| Audio (audition and ambient sound) | FR-R02G2006-006 |
| Haptics | FR-R02G2006-003 |
| No Stage One breakage | FR-R02G2006-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G20-07); no new levels; no purchases, ads or tracking; no recorded audio; no
  device run before ImplementationLock-100; no availability before X-R02-G20.
