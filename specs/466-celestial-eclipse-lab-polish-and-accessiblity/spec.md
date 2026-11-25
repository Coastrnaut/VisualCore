# Feature Specification: R02-G17-06 — Celestial Eclipse Lab: polish and accessibility

**Feature Branch**: `466-celestial-eclipse-lab-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G17-06 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1706-###,
SC-R02G1706-###, T-R02G1706-###

**Input**: User description: the archived R02-G17-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Celestial Eclipse Lab, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/466-celestial-eclipse-lab-polish-and-accessiblity` (the archived spelling of
  the directory is kept); FR-R02G1706-###, SC-R02G1706-###, T-R02G1706-###.
- **Packaging (ADR-0009):** polish and accessibility live in the experience `r02-g17.celestial-eclipse-lab` (a
  registered candidate since R02-G17-03) inside the one app; no app target, bundle identifier, scheme or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and "content count 74" (the 100
  certified levels stand); entitlement is the shared purchase controller's, tier free. **Device-only items:** sound,
  haptics and VoiceOver on D1/D2/D3, recorded as `{device}` items for after ImplementationLock-100. **Owner-only
  items:** none.
- **Shared features used:** R02-F26 (input and accessibility contract, shared feedback route), the shared ambient loop
  player, and the kernel, content, adapter, renderer, gestures and teaching of R02-G17-01 … 05.
- **Model:** feature 456 (Starlit Cartouche's polish and accessibility), adapted to phase changes, the clock run and
  eclipse failures.

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
456's answers where the games agree. Facts checked in code (read-only, 2026-11-25): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` are those feature 456 used; the kernel names bodies
"body j" (0 … 5) and eclipses "body f in front of body b", and the progress reads "m of n eclipses in order; next: …
between tick o and tick c; a run now would win (fail); a actions left"; a phase change spends one action and never ends
the level, the run (`clock.run`) always ends it, won or failed; the halos pulse by `u_pulse` (0.85 … 1, period 2.4 s, 1
under Reduce Motion); the won look is `u_won`, switched at once today, lighting the target brackets gold and flaring
matched halos, and the fallback colours by its `wonLevel`; the glow gain is capped by `u_glowLimit` (0.5 under Reduce
Flashing); the refusal codes are `r02-g17.level`, `action`, `budget`, `stage`, `stale`, `not-whole`, `choice`, `tick`,
`locked` and `date` (reported by the engine as `action.rule.<code>`).

- Q: What exactly is announced, and with which kind? → A: after an accepted action (`state`), the change then the
  progress: a phase change "Body j set to phase p."; undo and redo "Undone." / "Redone."; each followed by " m of n
  eclipses in order, a run now would win (or fail), a actions left." ("1 action left" singular); a win (`outcome`):
  "The eclipses came in the target order. Level won spending a actions, k of 3 stars." (without the stars in
  practice); a failure (`outcome`): the failure explanation of feature 465; a level or mode change (`level`): "Level n,
  band b, <mode>." with the tutorial instruction when shown; a refusal (`rejection`) in words: `r02-g17.locked` "That
  level is not open yet.", `r02-g17.date` "That date cannot be used.", `r02-g17.action` "That phase change, undo or redo
  cannot be made now.", `r02-g17.budget` "No actions are left: undo or retry.", `r02-g17.stage` "The level has ended.",
  `r02-g17.not-whole` "That value must be a whole number.", `r02-g17.choice` "That body is not in this level.",
  `r02-g17.tick` "That tick is outside the timeline.", any other code "That action was refused." (the engine's
  `action.rule.` prefix read as the bare code). A revealed hint is announced (`state`) with its text. Choosing a body,
  pending phase texts, the shown tick and orbit are not announced. Texts are a pure function of the old and new core
  (and the refusal code), so tests compare them exactly; the panel shows the same refusal text. Impact: FR-R02G1706-002;
  SC-R02G1706-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted phase change, undo or redo;
  `success` for a won run; `warning` for a failed run; `error` for a refusal; choosing a body, the pending texts, the
  shown tick, orbit and level changes play none. The run plays only its outcome. The shared planners' intervals apply.
  Impact: FR-R02G1706-003; SC-R02G1706-002.
- Q: How are fades done and measured under Reduce Flashing? → A: as feature 456: the presenter keeps light levels for
  the glow (0.7 while playing, 1 once won, 0.35 once failed) and the won look (1 once won, else 0), each easing toward
  its target by the frame clock's elapsed time between drawn frames (0.15 s normally, 0.45 s under Reduce Flashing,
  linear; under Reduce Flashing a fade that has started finishes before it may turn back); the scene draws the eased
  levels (the glow gain times the glow level, `u_won` the won level, and in the fallback the won colours by the won
  level, rebuilt when the level moves by a tenth or more); the state and digest never see them. Bodies, shadows,
  predicted eclipses and gauges change only with the player's actions and are not faded. The halo pulse (0.42 cycles
  per second, far below 3) is held at 1 under Reduce Motion and under Reduce Flashing, so the sky is still between
  actions under either. The measure: sampling the drawn levels every 1/60 s through a scripted win and adversarial
  flicker (a phase change undone and redone every frame, retry, level changes), no element crosses half its range more
  than 3 times per second, and every complete one-way fade of more than half the range takes at least 0.4 s under
  Reduce Flashing. Impact: FR-R02G1706-004; SC-R02G1706-003.
- Q: Where does the sound choice live, and what are the audition and ambient recipes? → A: a Sound toggle in the panel,
  off by default, held by the presenter (presentation only; saving it is R02-G17-07). Body j's tone is 220 Hz ×
  2^(2j / 12) (a whole tone per body, at most ten semitones above). The audition of a chosen body is a pure function of
  its index and whether it takes part in an eclipse of the predicted timeline: one that does sounds its tone and its
  fifth (× 3/2) at gain 0.04 each, a clean chord; one that does not sounds its tone with a second partial detuned upward
  by 3 Hz, so it beats audibly; 0.6 s with a linear decay to silence; played once per body choice, a new one replacing
  the last. The ambient recipe is a pure function of the eclipses matched in order, the actions left as a share of the
  budget and the stage: a root at 110 Hz times (1, 9/8, 5/4, 4/3) for more than three quarters of the actions left, more
  than half, more than a quarter, or less; one partial per quarter of the target matched (floor of four times matched
  over the target count, up to four), at the root times (5/4, 3/2, 2, 5/2)[k − 1], each with the base gain; the root
  alone when less than a quarter is matched; an added octave when won and halved gains when failed; the loop's length is
  the longest the shared player accepts at which every partial has a whole number of cycles (tested). The presenter
  rebuilds the loop only when the level opens, an action, undo, redo or the run changes the quarters, the root step or
  the stage, or the toggle turns on, never per frame. Sound plays exactly while the choice is on, the controls are on
  screen and the scene is active. Impact: FR-R02G1706-006; SC-R02G1706-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the chosen body
  and its pending phase are accessibility-adjustable elements with their labels and values in words ("body j, phase p
  of q" and "pending phase p"); a summary element reads "a actions left. <the progress in words>. Chosen: body j at
  phase p. Level: <the level in words>." (p the pending phase, the current one when no change is pending); on iPad the
  panel keeps a readable width (at most 520 points). Impact: FR-R02G1706-001, 005; SC-R02G1706-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Celestial Eclipse Lab with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the level's state (the target eclipses in order with their windows, how many are
matched, whether a run now would win, the chosen planet and its phase, the shown tick, the actions left), choose a
planet, change its phase, run the clock, undo and redo, ask for hints, read failures, choose levels and modes, and hear
every change and result, without seeing the sky. Planets and targets are named by number (a planet is spoken as "body
j", the kernel's word), so no colour or shape needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the chosen planet and its pending phase are
adjustable; every accepted phase change, run, undo, redo, refusal, win, failure and level change produces one
announcement through the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player sets a planet's phase, **Then** it is applied and one announcement
   names the change, the eclipses matched in order and the actions left.
2. **Given** a run fails, **When** the level fails, **Then** the failure explanation is announced as an outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get a still sky, no flashing, text
that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns; corona halos that pulse and flare
on a win are bright, moving subjects.

**Independent Test**: with Reduce Flashing, no faded element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, two frames of the same state at different times are identical; the panel lays
out at the largest accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** the level is won or fails, **Then** every change of the glow and of the won look
   is a fade of at least 0.4 s, not a flash (what the player's action changes — the planets' phases, the predicted
   eclipses, the gauges — appears with the action).
2. **Given** Reduce Motion or Reduce Flashing, **When** two frames of the same state are drawn at different times
   (after any fade has finished), **Then** they are identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted phase change, undo or redo gives a light selection haptic; a win a success haptic; a failure a warning; a
refused action an error haptic; all subject to the person's haptics switch. Choosing a planet plays a short tone made
in code from that planet and the eclipses it takes part in (the audition), and an optional ambient sound, made in code
from the eclipses matched, the actions left and the stage, plays while the experience is on screen and the sound choice
is on, and falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the audition and
ambient recipes are pure functions of the state they are made from; sound plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid phase changes, undos and redos):** haptics and announcements obey the shared rate limits
  (a burst of announcements posts its newest); an outcome is never lost.
- **A run, which always ends the level:** only the outcome (win or failure) is announced and felt.
- **Choosing a planet, pending phase drags, the shown tick and orbit:** not announced (the adjustable planet and phase
  speak their own values); choosing a planet plays its audition only when the sound choice is on.
- **A planet that takes part in no predicted eclipse:** its audition is audibly different, never silence.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** no sound starts or it stops; the game is unaffected and the sound choice
  stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1706-001**: Every native control (planet, phase, set phase, shown tick, run, undo, redo, hint, dismiss,
  level picker, modes, next level, reset view, sound) MUST have an accessibility label and value, a summary element
  MUST read the actions left, the eclipses matched and the next target with its window, the chosen planet and its
  phase, and the chosen planet and its pending phase MUST be adjustable with VoiceOver.
- **FR-R02G1706-002**: Every accepted phase change, undo and redo MUST be announced with what changed, the eclipses
  matched and the actions left (kind `state`); wins and failures (with the explanation) as `outcome`; level and mode
  changes as `level`; refusals in words as `rejection`, through the shared route.
- **FR-R02G1706-003**: Haptics MUST map selection → accepted phase change, undo or redo, success → win, warning →
  failure, error → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G1706-004**: Reduce Flashing MUST cap the glow and turn every brightness change of the glow and of the won
  look into fades of at least 0.4 s, with every periodic motion below 3 cycles per second; Reduce Motion and Reduce
  Flashing MUST keep the sky still between actions (the halo pulse held); neither changes the state or its digest.
- **FR-R02G1706-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G1706-006**: A planet's audition and an optional ambient sound MUST be synthesized in code — the audition from
  the chosen planet (its index and whether it takes part in a predicted eclipse), the ambient sound from the eclipses
  matched, the actions left and the stage — play only while wanted, on screen and active, and never touch audio when
  off.
- **FR-R02G1706-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the glow and the won look, eased by the frame clock's elapsed time.
- **Audition recipe**: partials (frequencies, gains, decay) derived from a chosen planet.
- **Ambient recipe**: partials (frequencies, gains) derived from the eclipses matched, the actions left and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1706-001**: 100 % of native controls expose a label and value; level 1 is completed using only the
  operations the accessibility actions perform (the planet and phase increments and decrements, Set phase and Run),
  with every step announced.
- **SC-R02G1706-002**: For scripted sequences of phase changes, undos, refusals, wins and failures, the recorded
  announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G1706-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G1706-004**: The audition and ambient recipes are identical for equal states and differ when they differ;
  sound plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G1706-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.
- **SC-R02G1706-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G17-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G17-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log and the refusal
  log.
- Error handling: a refused action changes nothing and is explained in words; an unavailable audio session leaves the
  game silent and playable.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G1706-001, 005 |
| Accessibility (planets and targets by number; eclipses matched in words) | FR-R02G1706-001, 002, 005 |
| Reduce flashing | FR-R02G1706-004 |
| Audio (audition and ambient sound) | FR-R02G1706-006 |
| Haptics | FR-R02G1706-003 |
| No Stage One breakage | FR-R02G1706-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G17-07); no new levels; no purchases, ads or tracking; no recorded audio; no
  device run before ImplementationLock-100; no availability before X-R02-G17.
