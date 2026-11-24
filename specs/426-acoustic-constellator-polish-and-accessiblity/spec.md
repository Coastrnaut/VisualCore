# Feature Specification: R02-G13-06 — Acoustic Constellator: polish and accessibility

**Feature Branch**: `426-acoustic-constellator-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G13-06 (migration ledger, game feature of experience R02-G13) · ID namespace FR-R02G1306-###,
SC-R02G1306-###, T-R02G1306-###

**Input**: User description: the archived R02-G13-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Acoustic Constellator, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/426-acoustic-constellator-polish-and-accessiblity` (the archived spelling of the
  directory is kept); FR-R02G1306-###, SC-R02G1306-###, T-R02G1306-###.
- **Packaging (ADR-0009):** polish and accessibility live in the experience `r02-g13.acoustic-constellator` (a
  registered candidate since R02-G13-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and "content count 85" (the 100 certified
  levels stand). **Device-only items:** sound, haptics and VoiceOver on D1/D2/D3, recorded as `{device}` items for after
  ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F26 (input and accessibility contract, shared feedback route), the shared ambient loop
  player, and the kernel, content, adapter, renderer, gestures and teaching of R02-G13-01 … 05.
- **Model:** feature 416 (Harmonic Bridges' polish and accessibility).

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
416's answers where the games agree. Facts checked in code (read-only, 2026-11-23): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` are those feature 416 used; Acoustic Constellator's
stars pulse by a uniform and level-0 adds two wave shells per star on a coherent shown tick, the shown tick advances
every 0.25 s and holds the last tick 1 s, and the won look reaches the symbol links through the `wonLink` material and
the `.wonGlow` glow strips, which switch at once when the level is won; a listen always ends the level (won or failed);
the adapter's refusal codes are `r02-g13.action`, `stage`, `stale`, `level`, `malformed`, `locked`, `date` and
`not-whole` (reported by the engine as `action.rule.<code>`), which the panel words through
`AcousticConstellatorMirror.refusalText`; the level words stars "star i, rate r, phase p", links "link star a to star b,
gap g" and progress "tick t of w: order …, threshold θ, coherent, run r of h, k links snapped; …; a actions left".

- Q: What exactly is announced, and with which kind? → A: after an accepted action (`state`), the change then the
  progress: a link "Linked star a to star b, gap g."; an unlink "Unlinked star a and star b."; a nudge "Star s nudged to
  phase p."; undo and redo "Undone." / "Redone."; each followed by " k symbol pairs missing, a actions left." (" The
  symbol is linked, a actions left." when none is missing); a win (`outcome`): "The symbol rings together. Level won
  spending a actions, k of 3 stars." (without the stars in practice); a failure (`outcome`): the failure explanation of
  feature 425; a level or mode change (`level`): "Level n, band b, <mode>." with the tutorial instruction when shown; a
  refusal (`rejection`) in words: `r02-g13.locked` "That level is not open yet.", `r02-g13.date` "That date cannot be
  used.", `r02-g13.action` "That change is not allowed for these stars.", `r02-g13.stage` "The level has ended.",
  `r02-g13.not-whole` "That value must be a whole number.", any other code "That action was refused." (the engine's
  `action.rule.` prefix read as the bare code). A revealed hint is announced (`state`) with its text. Choosing a star or
  partner, a drag preview and orbit are not announced. Texts are a pure function of the old and new core (and the
  refusal code), so tests compare them exactly; the panel shows the same refusal text. Impact: FR-R02G1306-002;
  SC-R02G1306-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted link, unlink, nudge, undo or redo;
  `success` for a win; `warning` for a failure; `error` for a refusal; choosing, the drag preview, orbit and level
  changes play none. A listen always ends the level, so it plays only its outcome; an action that spends the last move
  without a win plays only the warning. The shared planners' intervals apply. Impact: FR-R02G1306-003; SC-R02G1306-002.
- Q: How are fades done and measured under Reduce Flashing? → A: the presenter keeps light levels for the glow (0.7
  while playing, 1 once won, 0.35 once failed) and the won brightening (1 once won, else 0), each easing toward its
  target in presentation time (0.15 s normally, 0.45 s under Reduce Flashing, linear; under Reduce Flashing a fade that
  has started finishes before it may turn back); the scene draws the eased levels (the glow gain times the glow level,
  and the won look scaled by its level through a uniform, so the `wonLink` material and the `.wonGlow` strips no longer
  switch the brightness at once); the state and digest never see them. The tick preview changes which links are teal
  and which hands point where every 0.25 s, so under Reduce Flashing the shown tick is held (tick 0) exactly as under
  Reduce Motion, the stars do not pulse and no wave shell is drawn; links, hands and gauges change only with the
  player's actions and are not faded. The measure: sampling the drawn levels every 1/60 s through a scripted win and
  adversarial flicker (a link undone and redone every frame, retry, level changes), no element crosses half its range
  more than 3 times per second, and every complete one-way fade of more than half the range takes at least 0.4 s under
  Reduce Flashing; with Reduce Flashing no wave shell is drawn in any frame. Impact: FR-R02G1306-004; SC-R02G1306-003.
- Q: Where does the sound choice live, and what are the audition and ambient recipes? → A: a Sound toggle in the panel,
  off by default, held by the presenter (presentation only; saving it is R02-G13-07). A star's tone is
  220 Hz × 2^(rate / 12) (its natural rate 0 … 11 as semitones). The audition of an inspected link is a pure function
  of its two stars' rates and their phase gap g (0 … 6) at the shown tick: the two tones at gain 0.04 each, the second
  detuned upward by g × 1.5 Hz so that a wide gap beats audibly and a gap of 0 is a clean chord; 0.6 s with a linear
  decay to silence; played once per inspection, a new one replacing the last. The ambient recipe is a pure function of
  the stars' rates, the coherence bars lit (0 … 12) at the last tick of the current listen report, the hold run, the
  actions left as a share of the budget and the stage: a root at 110 Hz times (1, 9/8, 5/4, 4/3) for more than three
  quarters of the actions left, more than half, more than a quarter, or less; one partial per lit quarter of the
  coherence gauge (up to four), at the root times (5/4, 3/2, 2, 5/2)[k − 1], each with the base gain; the root alone when
  no quarter is lit; an added octave when won and halved gains when failed; the loop's length is the longest the shared
  player accepts at which every partial has a whole number of cycles (tested). The presenter rebuilds the loop only when
  the level opens, an action, undo or redo changes the lit quarters, the root step or the stage, or the toggle turns on,
  never per frame. Sound plays exactly while the choice is on, the controls are on screen and the scene is active.
  Impact: FR-R02G1306-006; SC-R02G1306-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the chosen star
  and partner are accessibility-adjustable elements with their labels and values in words (the star as the level words
  it, with its rate and phase; the partner likewise and whether the pair is linked); a summary element reads "a actions
  left. k symbol pairs missing. Tick t: coherence c of 12, run r of h. Chosen: <the star in words> and <the partner in
  words>. Level: <the level in words>."; on iPad the panel keeps a readable width (at most 520 points). Impact:
  FR-R02G1306-001, 005; SC-R02G1306-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Acoustic Constellator with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the level's state (the stars with their rates and phases, the links and which
are fixed, the symbol pairs still missing, the coherence, the hold run, the actions left), choose a star and a partner,
link, unlink, nudge, listen, undo and redo, ask for hints, read failures, choose levels and modes, and hear every change
and result, without seeing the constellation. Stars are named by number, rate and phase, links by their two stars and
gap, so no colour or shape needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the chosen star and partner are adjustable; every
accepted link, unlink, nudge, listen, undo, redo, refusal, win, failure and level change produces one announcement
through the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player links two stars, **Then** it is applied and one announcement names the
   link, its gap, the symbol pairs still missing and the actions left.
2. **Given** a listen fails, **When** the level fails, **Then** the failure explanation is announced as an outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get still stars, no flashing, text
that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns; pulsing stars, expanding wave shells
and brightening links are moving, bright subjects.

**Independent Test**: with Reduce Flashing, no faded element changes brightness more than three times a second, no wave
shell is drawn, the shown tick is held and the glow stays capped; with Reduce Motion, the stars do not pulse and the
shown tick is held; the panel lays out at the largest accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a link is made, a phase nudged, the level is won or it fails, **Then** no wave
   shell is drawn and every change of the glow and of the won brightening of the links is a fade of at least 0.4 s, not
   a flash (what the player's action changes — links, hands, gauges — appears with the action).
2. **Given** Reduce Motion or Reduce Flashing, **When** two frames of the same state are drawn at different times (after
   any fade has finished), **Then** they are identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted link, unlink, nudge or listen gives a light selection haptic; a win a success haptic; a failure a warning;
a refused action an error haptic; all subject to the person's haptics switch. Inspecting a link plays a short two-tone
chord made in code from its two stars (the audition), and an optional ambient sound, made in code from the stars'
phases, the coherence, the hold run, the actions left and the stage, plays while the experience is on screen and the
sound choice is on, and falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the audition and
ambient recipes are pure functions of the state they are made from; sound plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid links, nudges, undos and redos):** haptics and announcements obey the shared rate limits
  (a burst of announcements posts its newest); an outcome is never lost.
- **An action that ends the level:** only the outcome is announced and felt.
- **Choosing a star or partner, a drag preview and orbit:** not announced (the adjustable star and partner speak their
  own values); inspecting a link plays its audition only when the sound choice is on.
- **A link whose stars are in phase:** its audition is a consonant chord; a wide gap is audibly beating, never silence.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** no sound starts or it stops; the game is unaffected and the sound choice
  stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1306-001**: Every native control (star and partner, link, unlink, nudge, listen, undo, redo, hint, dismiss,
  retry, level picker, modes, next level, reset view, sound) MUST have an accessibility label and value, a summary
  element MUST read the actions left, the missing symbol pairs, the coherence and hold run at the shown tick and the
  chosen star and partner, and the chosen star and partner MUST be adjustable with VoiceOver.
- **FR-R02G1306-002**: Every accepted link, unlink, nudge, listen, undo and redo MUST be announced with what changed and
  the actions left (kind `state`); wins and failures (with the explanation) as `outcome`; level and mode changes as
  `level`; refusals in words as `rejection`, through the shared route.
- **FR-R02G1306-003**: Haptics MUST map selection → accepted link, unlink, nudge, listen, undo or redo, success → win,
  warning → failure, error → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G1306-004**: Reduce Flashing MUST cap the glow, turn every brightness change of the glow and of the won
  brightening of the links into fades of at least 0.4 s, hold the shown tick, stop the pulse and draw no wave shells,
  with every periodic motion below 3 cycles per second; Reduce Motion MUST stop the pulse and hold the shown tick;
  neither changes the state or its digest.
- **FR-R02G1306-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G1306-006**: A link's audition and an optional ambient sound MUST be synthesized in code — the audition from
  the link's two stars (their rates and their phase gap at the shown tick), the ambient sound from the stars' phases, the
  coherence, the hold run, the actions left and the stage — play only while wanted, on screen and active, and never
  touch audio when off.
- **FR-R02G1306-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the glow and the won brightening of the links, eased in presentation time.
- **Audition recipe**: partials (frequencies, gains, decay) derived from a link's two stars.
- **Ambient recipe**: partials (frequencies, gains) derived from the stars' phases, the coherence, the hold run, the
  actions left and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1306-001**: 100 % of native controls expose a label and value; level 1 is completed using only the
  operations the accessibility actions perform (the star and partner increment and decrement, Link, Nudge and Listen),
  with every step announced.
- **SC-R02G1306-002**: For scripted sequences of links, unlinks, nudges, listens, undos, refusals, wins and failures, the
  recorded announcements and haptics equal the plan exactly (kinds and texts).
- **SC-R02G1306-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G1306-004**: The audition and ambient recipes are identical for equal states and differ when they differ; sound
  plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G1306-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.
- **SC-R02G1306-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G13-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G13-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log and the refusal
  log.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G1306-001, 005 |
| Accessibility (stars by number, rate and phase; links by stars and gap) | FR-R02G1306-001, 002, 005 |
| Reduce flashing | FR-R02G1306-004 |
| Audio (audition and ambient sound) | FR-R02G1306-006 |
| Haptics | FR-R02G1306-003 |
| No Stage One breakage | FR-R02G1306-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G13-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100; no availability before X-R02-G13.
