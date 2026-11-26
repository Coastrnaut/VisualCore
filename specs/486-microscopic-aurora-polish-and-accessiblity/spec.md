# Feature Specification: R02-G19-06 — Microscopic Aurora: polish and accessibility

**Feature Branch**: `486-microscopic-aurora-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G19-06 (migration ledger, game feature of experience R02-G19) · ID namespace FR-R02G1906-###,
SC-R02G1906-###, T-R02G1906-###

**Input**: User description: the archived R02-G19-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Microscopic Aurora, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/486-microscopic-aurora-polish-and-accessiblity` (the archived spelling of the
  directory is kept); FR-R02G1906-###, SC-R02G1906-###, T-R02G1906-###.
- **Packaging (ADR-0009):** polish and accessibility live in the experience `r02-g19.microscopic-aurora` (a registered
  candidate since R02-G19-03) inside the one app; no app target, bundle identifier, scheme or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and "content count 82" (the 100
  certified levels stand); entitlement is the shared purchase controller's, tier free. **Device-only items:** sound,
  haptics and VoiceOver on D1/D2/D3, recorded as `{device}` items for after ImplementationLock-100. **Owner-only
  items:** none.
- **Shared features used:** R02-F26 (input and accessibility contract, shared feedback route), the shared ambient loop
  player, and the kernel, content, adapter, renderer, gestures and teaching of R02-G19-01 … 05.
- **Model:** feature 476 (Apsides Workshop's polish and accessibility), adapted to well placements on sites, the play
  of one swim, the stencil's coverage and connectedness, and the swarm's exits and splits.

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
476's answers where the games agree. Facts checked in code (read-only, 2026-11-26): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` are those feature 476 used; the kernel names cells
"row r, column c", a well "well n at row r, column c, strength s, clockwise" (or "counterclockwise", or "well n empty"),
the coverage "stencil l of S cells lit, x.x %, needs y.y %" and the progress as "<the wells>; <the coverage>; playing
now would win (or fail: <reason>); a actions left"; a placement (`well.place`) or removal (`well.remove`) spends one
action and never ends the level, the play (`swim.play`) always ends it, won or failed; nothing in the dish moves by
time (the shown tick is presentation state, never advanced by a clock); the won look is `u_won`, switched at once today,
brightening the ribbons and lighting every stencil cell, and the fallback draws the won marks in its colours; the glow
gain is capped by `u_glowLimit` (lower under Reduce Flashing); a well can be placed on a level site no other well holds;
the refusal codes are `r02-g19.level`, `action`, `budget`, `stage`, `stale`, `not-whole`, `tick`, `locked` and `date`
(reported by the engine as `action.rule.<code>`).

- Q: What exactly is announced, and with which kind? → A: after an accepted action (`state`), the change then the
  progress: "Well n placed at row r, column c, strength s, clockwise." (or "counterclockwise") / "Well n removed.";
  undo and redo "Undone." / "Redone."; each followed by " l of S stencil cells lit, playing now would win (or fail), a
  actions left." ("1 action left" singular); a win (`outcome`): "The trails covered the stencil as one pattern. Level won
  spending a actions, k of 3 stars." (without the stars in practice); a failure (`outcome`): the failure explanation of
  feature 485; a level or mode change (`level`): "Level n, band b, <mode>." with the tutorial instruction when shown; a
  refusal (`rejection`) in words: `r02-g19.locked` "That level is not open yet.", `r02-g19.date` "That date cannot be
  used.", `r02-g19.action` "That well cannot be placed there, or there is nothing to remove, undo or redo.",
  `r02-g19.budget` "No actions are left: undo or retry.", `r02-g19.stage` "The level has ended.", `r02-g19.stale` "The
  play changed before the action arrived.", `r02-g19.level` "That level could not be made.", `r02-g19.not-whole` "That
  value must be a whole number.", `r02-g19.tick` "That tick is outside the swim.", any other code "That action was
  refused." (the engine's `action.rule.` prefix read as the bare code). A revealed hint is announced (`state`) with its
  text. Changing the panel's selection, drag previews, the shown tick, the freeze, the view, dismissing the tutorial and
  the Sound toggle are not announced (the controls speak their own values). Texts are a pure function of the old and new
  core (and the refusal code), so tests compare them exactly; the panel shows the same refusal text. Impact:
  FR-R02G1906-002; SC-R02G1906-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted placement, removal, undo or redo;
  `success` for a won play; `warning` for a failed play; `error` for a refusal; changing the selection, previews, the
  shown tick, the freeze, the view and level changes play none. The play plays only its outcome. The shared planners'
  intervals apply. Impact: FR-R02G1906-003; SC-R02G1906-002.
- Q: How are fades done and measured under Reduce Flashing? → A: as feature 476: the presenter keeps light levels for
  the glow (0.7 while playing, 1 once won, 0.35 once failed) and the won look (1 once won, else 0), each easing toward
  its target by the frame clock's elapsed time between drawn frames (0.15 s normally, 0.45 s under Reduce Flashing,
  linear; under Reduce Flashing a fade that has started finishes before it may turn back); the scene draws the eased
  levels (the glow gain times the glow level, `u_won` the won level, and in the fallback the won colours by the won
  level, rebuilt when the level moves by a tenth or more); the state and digest never see them. The wells, ribbons,
  swimmers, lit cells and gauges change only with the player's actions and are not faded. Nothing else moves by time,
  so the dish is still between actions under Reduce Motion and under Reduce Flashing. The measure: sampling the drawn
  levels every 1/60 s through a scripted win and adversarial flicker (a placement undone and redone every frame, retry,
  level changes), no element crosses half its range more than 3 times per second, and every complete one-way fade of
  more than half the range takes at least 0.4 s under Reduce Flashing. Impact: FR-R02G1906-004; SC-R02G1906-003.
- Q: Where does the sound choice live, and what are the audition and ambient recipes? → A: a Sound toggle in the panel,
  off by default, held by the presenter (presentation only; saving it is R02-G19-07). The selected well's tone is
  220 Hz × 2^(n / 12) with n = 3 × (strength − 1) (0, 3, 6, 9: a stronger well sounds higher); the sense sets the second
  partial: a well that can be placed sounds its tone and the tone × (3/2 clockwise, 4/3 counterclockwise) at gain 0.04
  each, a clean interval; one that cannot be placed (its site held by another well, or no site) sounds its tone with a
  second partial detuned upward by 3 Hz, so it beats audibly; 0.6 s with a linear decay to silence; played once per
  change of the panel's selection (slot, site, strength or sense), a new one replacing the last; never for drag
  previews. The audition is a pure function of (strength, sense, can be placed). The ambient recipe is a pure function
  of the stencil cells lit, the cells the coverage needs, the actions left as a share of the budget and the stage: a
  root at 110 Hz times (1, 9/8, 5/4, 4/3) for more than three quarters of the actions left, more than half, more than a
  quarter, or less; one partial per quarter of the needed cells lit (floor of four times lit over needed, up to four),
  at the root times (5/4, 3/2, 2, 5/2)[q − 1] for q = 1 … quarters, each with the base gain; the root alone when less
  than a quarter is lit; an added octave when won and halved gains when failed; the loop's length is the longest the
  shared player accepts at which every partial has a whole number of cycles (tested). The presenter rebuilds the loop
  only when the level opens, a placement, removal, undo, redo or the play changes the quarters, the root step or the
  stage, or the toggle turns on, never per frame. Sound plays exactly while the choice is on, the controls are on screen
  and the scene is active. Impact: FR-R02G1906-006; SC-R02G1906-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the panel's slot,
  site and strength are accessibility-adjustable elements with their labels and values in words ("well n", "site at row
  r, column c", "strength s") and the sense a toggle with its value ("clockwise" or "counterclockwise"); a summary
  element reads "a actions left. <the progress in words>. Selected: well n at row r, column c, strength s, <sense>.
  Level: <the level in words>." (no site when the level has none); on iPad the panel keeps a readable width (at most 520
  points). Impact: FR-R02G1906-001, 005; SC-R02G1906-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Microscopic Aurora with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the level's state (the wells by slot with their sites, strengths and senses,
the stencil cells lit of those needed, whether playing now would win and why not, the panel's selected well, the shown
tick, the actions left), place and remove wells, play the swim, undo and redo, ask for hints, read failures, choose
levels and modes, and hear every change and result, without seeing the dish. Sites, wells, swimmers and cells are named
by number or by row and column, so no colour or shape needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the panel's slot, site and strength are adjustable;
every accepted placement, removal, play, undo, redo, refusal, win, failure and level change produces one announcement
through the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player places or removes a well, **Then** it is applied and one announcement
   names the change, the stencil cells lit and the actions left.
2. **Given** a play fails, **When** the level fails, **Then** the failure explanation is announced as an outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get a still dish, no flashing, text
that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns; luminous swimmers and ribbons that
flare on a win are bright subjects.

**Independent Test**: with Reduce Flashing, no faded element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, two frames of the same state at different times are identical; the panel lays
out at the largest accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** the level is won or fails, **Then** every change of the glow and of the won look
   is a fade of at least 0.4 s, not a flash (what the player's action changes — the wells, the ribbons, the lit cells,
   the gauges — appears with the action).
2. **Given** Reduce Motion or Reduce Flashing, **When** two frames of the same state are drawn at different times
   (after any fade has finished), **Then** they are identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted placement, removal, undo or redo gives a light selection haptic; a win a success haptic; a failure a
warning; a refused action an error haptic; all subject to the person's haptics switch. Choosing the panel's well plays
a short tone made in code from that well (the audition), and an optional ambient sound, made in code from the stencil
coverage, the actions left and the stage, plays while the experience is on screen and the sound choice is on, and falls
silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the audition and
ambient recipes are pure functions of the state they are made from; sound plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid placements, undos and redos):** haptics and announcements obey the shared rate limits (a
  burst of announcements posts its newest); an outcome is never lost.
- **A play, which always ends the level:** only the outcome (win or failure) is announced and felt.
- **Changing the panel's selection, drag previews, the shown tick, the freeze and the view:** not announced (the
  adjustable controls speak their own values); changing the selection plays its audition only when the sound choice is
  on.
- **A selected well that cannot be placed (its site is held by another well, or no site):** its audition is audibly
  different, never silence.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** no sound starts or it stops; the game is unaffected and the sound choice
  stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1906-001**: Every native control (slot, site, strength, sense, place, remove, shown tick, play, undo, redo,
  hint, dismiss, level picker, modes, next level, freeze, reset view, sound) MUST have an accessibility label and value,
  a summary element MUST read the actions left, the coverage and whether playing now would win, the wells and the
  selected well, and the panel's slot, site and strength MUST be adjustable with VoiceOver.
- **FR-R02G1906-002**: Every accepted placement, removal, undo and redo MUST be announced with what changed, the
  stencil cells lit and the actions left (kind `state`); wins and failures (with the explanation) as `outcome`; level
  and mode changes as `level`; refusals in words as `rejection`, through the shared route.
- **FR-R02G1906-003**: Haptics MUST map selection → accepted placement, removal, undo or redo, success → win, warning →
  failure, error → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G1906-004**: Reduce Flashing MUST cap the glow and turn every brightness change of the glow and of the won
  look into fades of at least 0.4 s, with every periodic motion below 3 cycles per second; Reduce Motion and Reduce
  Flashing MUST keep the dish still between actions; neither changes the state or its digest.
- **FR-R02G1906-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G1906-006**: A well audition and an optional ambient sound MUST be synthesized in code — the audition from
  the panel's selected well (its strength, its sense and whether it can be placed), the ambient sound from the stencil
  coverage, the actions left and the stage — play only while wanted, on screen and active, and never touch audio when
  off.
- **FR-R02G1906-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the glow and the won look, eased by the frame clock's elapsed time.
- **Audition recipe**: partials (frequencies, gains, decay) derived from the selected well.
- **Ambient recipe**: partials (frequencies, gains) derived from the coverage, the actions left and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1906-001**: 100 % of native controls expose a label and value; level 1 is completed using only the
  operations the accessibility actions perform (the slot, site and strength increments and decrements, the sense
  toggle, Place and Play), with every step announced.
- **SC-R02G1906-002**: For scripted sequences of placements, removals, undos, refusals, wins and failures, the recorded
  announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G1906-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G1906-004**: The audition and ambient recipes are identical for equal states and differ when they differ;
  sound plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G1906-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.
- **SC-R02G1906-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G19-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G19-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log and the refusal
  log.
- Error handling: a refused action changes nothing and is explained in words; an unavailable audio session leaves the
  game silent and playable.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G1906-001, 005 |
| Accessibility (sites, wells, swimmers and cells by number; coverage in words) | FR-R02G1906-001, 002, 005 |
| Reduce flashing | FR-R02G1906-004 |
| Audio (audition and ambient sound) | FR-R02G1906-006 |
| Haptics | FR-R02G1906-003 |
| No Stage One breakage | FR-R02G1906-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G19-07); no new levels; no purchases, ads or tracking; no recorded audio; no
  device run before ImplementationLock-100; no availability before X-R02-G19.
