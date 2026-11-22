# Feature Specification: R02-G08-06 — Faceted Forge: polish and accessibility

**Feature Branch**: `376-faceted-forge-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G08-06 (migration ledger, game feature of experience R02-G08) · ID namespace FR-R02G0806-###,
SC-R02G0806-###, T-R02G0806-###

**Input**: User description: the archived R02-G08-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Faceted Forge, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/376-faceted-forge-polish-and-accessiblity` (the source's spelling kept);
  FR-R02G0806-###, SC-R02G0806-###, T-R02G0806-###.
- **Packaging (ADR-0009):** polish lives in the experience `r02-g08.faceted-forge` (a registered candidate since
  R02-G08-03) inside the one app, through the app's shared feedback route and the shared ambient loop player.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, "content count 84". **Device-only
  items:** listening, feeling and VoiceOver use on D1/D2/D3, recorded as `{device}` tasks for after
  ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F26 (input and accessibility contract, feedback route), R02-F10 (reduce flashing and
  non-colour clues), R02-F27 (ambient audio), and the kernel, content, adapter, renderer, gestures and teaching of
  R02-G08-01 … 05.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
366's answers where the games agree. Facts checked in code (read-only, 2026-11-22): the shared `ExperienceFeedback`
route, `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`), `HapticKind` (`selection`, `success`, `warning`,
`error`) and `AmbientLoopPlayer` with a fixed `AmbientLoopRecipe` (1 … 6 partials, 4 … 16 s) are those feature 366
used; Faceted Forge's dispersion bands move at 0.8 rad/s per layer (at most 2.4 rad/s, about 0.38 cycles per second),
still under Reduce Motion (time 0); its glow limit is 0.5 under Reduce Flashing (1.5 otherwise); the sliver cross
appears at once on a sliver failure and the opening eases over 0.4 s from the level's start; the adapter's refusal codes
are `r02-g08.action`, `stage`, `stale`, `miss`, `malformed`, `locked`, `date` and `not-whole`; the presenter shows
refusals as "That change was refused: <code>" and logs their codes; pieces are named "piece k: s of the crystal, f
faces" (the whole crystal before the first cut).

- Q: What exactly is announced, and with which kind? → A: after an accepted cut (`state`): "Piece p cut in direction x
  at depth d: n pieces now. c cuts left." (c = budget − cuts; "1 cut left"); undo and redo: "Undone. " / "Redone. "
  followed by "n pieces. c cuts left."; a win (`outcome`): "The pieces match the target. Level won with m cuts made, k
  of 3 stars." (without the stars in practice); a failure (`outcome`): the failure explanation of feature 375; a level
  or mode change (`level`): "Level n, band b, <mode>." with the tutorial instruction when shown; a refusal (`rejection`)
  in words: `r02-g08.locked` "That level is not open yet.", `r02-g08.date` "That date cannot be used.", `r02-g08.action`
  "That cut is not possible here.", `r02-g08.miss` "That plane misses the piece.", `r02-g08.stage` "The level has
  ended.", `r02-g08.not-whole` "That value must be a whole number.", any other code "That move was refused." Changes of
  the preview choice (piece, direction, depth) are not announced: the adjustable pickers speak their own values. Texts
  are a pure function of the old and new core (and the refusal code), so tests compare them exactly; the panel shows the
  same refusal text. Impact: FR-R02G0806-002; SC-R02G0806-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted cut, undo or redo; `success` for a
  win; `warning` for a failure; `error` for a refusal; choice changes, level changes and drag previews play none. The
  shared planners' intervals apply; when one cut both moves and ends the play (the winning cut, a sliver or the last cut
  of the budget), only the outcome is planned, so an outcome is never dropped behind a selection haptic. Impact:
  FR-R02G0806-003; SC-R02G0806-002.
- Q: How are fades done and measured under Reduce Flashing? → A: the presenter keeps a light level for the cut-face
  glow (0.7 while playing, 1 once won, 0.35 once failed) and the sliver mark (1 while the failure is a sliver, else 0),
  each easing toward its target in presentation time (0.15 s normally, 0.45 s under Reduce Flashing, linear; under
  Reduce Flashing a fade that has started finishes before it may turn back), and the opening keeps its 0.4 s ease. The
  scene draws the eased levels (the glow gain times the glow level, the sliver cross's colour times its level); the
  state and digest never see them. The shimmer stays at about 0.38 cycles per second (below 3) and is still under Reduce
  Motion. The measure: sampling the drawn levels every 1/60 s through a scripted win and adversarial flicker (a sliver
  failure undone and repeated every frame, retry, level changes), no element crosses half its range more than 3 times
  per second, and every complete one-way fade of more than half the range takes at least 0.4 s under Reduce Flashing.
  Impact: FR-R02G0806-004; SC-R02G0806-003.
- Q: Where does the sound choice live, and what is the recipe? → A: a Sound toggle in the panel, off by default, held by
  the presenter (presentation only; saving it is R02-G08-07). The recipe is a pure function of the piece count, the
  target's piece count and the stage: a root at 110 Hz and one partial per piece beyond the first, up to four, at 110 ×
  (5/4, 3/2, 2, 5/2)[k − 1], each with the base gain, the root alone while the crystal is whole; an added octave when
  won and halved gains when failed; a 12-second loop (every partial has a whole number of cycles in it). The presenter
  rebuilds the loop only when the level opens, a cut, undo or redo changes the piece count or the stage, or the toggle
  turns on, never per frame. The loop plays exactly while the choice is on, the controls are on screen and the scene is
  active. Impact: FR-R02G0806-006; SC-R02G0806-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system text
  styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels, and uses
  system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the piece,
  direction and depth pickers are accessibility-adjustable elements labelled "Piece to cut" (value: the piece in
  words), "Direction of the cut" (value "direction x") and "Depth of the cut" (value "depth d", or "the plane misses
  this piece"); a summary element reads "c cuts left. n pieces: <each piece in words>. Target: <the target in words>.
  Next cut: piece p, direction x, depth d."; on iPad the panel keeps a readable width (at most 520 points). Impact:
  FR-R02G0806-001, 005; SC-R02G0806-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Faceted Forge with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the crystal's state (each piece's share of the crystal and face count, the
target pieces, the cuts left and the chosen piece, direction and depth), choose and cut pieces, ask for hints, read
failures, choose levels and modes, and hear every change and result, without seeing the crystal. Pieces are named by
number, share and face count and directions in words, so no colour or position needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the piece, direction and depth pickers are
adjustable; every accepted cut, undo, redo, refusal, win, failure and level change produces one announcement through the
shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player cuts a piece, **Then** the cut is applied and one announcement names
   the piece, the new pieces and the cuts left.
2. **Given** a cut leaves a sliver, **When** the level fails, **Then** the failure explanation is announced as an
   outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get a still crystal, no flashing,
text that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns.

**Independent Test**: with Reduce Flashing, no drawn element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, the shimmer and the opening are still; the panel lays out at the largest
accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** a cut splits a piece, the level is won or a sliver fails it, **Then** every
   brightness change is a fade of at least 0.4 s, not a flash.
2. **Given** Reduce Motion, **When** two frames of the same state are drawn at different times, **Then** they are
   identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted cut gives a light selection haptic; a win a success haptic; a failure a warning; a refused action an
error haptic; all subject to the person's haptics switch. An optional ambient sound, made in code from the pieces
against the target and the stage, plays while the experience is on screen and the sound choice is on, and falls silent
off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the ambient recipe is a
pure function of the pieces and the stage; the loop plays only while wanted, on screen and active.

### Edge Cases

- **Many quick actions (rapid cuts, undos and redos):** haptics and announcements obey the shared rate limits (a burst
  of announcements posts its newest); an outcome is never lost.
- **A drag in progress:** the previewed plane is described but not announced; the committed cut is announced like any
  other.
- **A cut that ends the level:** only the outcome is announced and felt.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** the loop does not start or stops; the game is unaffected and the sound
  choice stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0806-001**: Every native control (piece, direction and depth pickers, cut, undo, redo, hint, dismiss, retry,
  level picker, modes, next level, reset view, sound) MUST have an accessibility label and value, a summary element
  MUST read the cuts left, every piece's share and face count, the target and the chosen cut, and the pickers MUST be
  adjustable with VoiceOver.
- **FR-R02G0806-002**: Every accepted cut, undo and redo MUST be announced with what changed and the cuts left (kind
  `state`); wins and failures (with the explanation) as `outcome`; level and mode changes as `level`; refusals in
  words as `rejection`, through the shared route.
- **FR-R02G0806-003**: Haptics MUST map selection → accepted cut, undo or redo, success → win, warning → failure, error
  → refused action, through the shared route and the person's switch; they never change state.
- **FR-R02G0806-004**: Reduce Flashing MUST cap the glow and turn every brightness change of the cut-face glow, the
  sliver mark and the opening into fades of at least 0.4 s, with the shimmer below 3 cycles per second; Reduce Motion
  MUST hold the shimmer and the opening still; neither changes the state or its digest.
- **FR-R02G0806-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping.
- **FR-R02G0806-006**: An optional ambient sound MUST be synthesized in code from the pieces against the target and the
  stage, play only while wanted, on screen and active, and never touch audio when off.
- **FR-R02G0806-007**: Existing tests pass; no state or digest change; new public names documented; the reference
  regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the cut-face glow, the sliver mark and the opening, eased in presentation time.
- **Ambient recipe**: partials (frequencies, gains) derived from the pieces and the stage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0806-001**: 100 % of native controls expose a label and value; level 1 is completed using only the operations
  the accessibility actions perform (the pickers' increment and decrement, depth − and +, cut), with every step
  announced.
- **SC-R02G0806-002**: For scripted sequences of cuts, undos, refusals, wins and failures, the recorded announcements
  and haptics equal the plan exactly (kinds and texts).
- **SC-R02G0806-003**: With Reduce Flashing, no drawn element crosses half its brightness range more than 3 times per
  second over a scripted win and adversarial flicker, and every complete one-way fade of more than half the range takes
  at least 0.4 s; with Reduce Motion, two frames of the same state at different times are identical.
- **SC-R02G0806-004**: The ambient recipe is identical for equal pieces and stages and differs when they differ; the
  loop plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G0806-005**: Existing tests pass unchanged except where this feature adds wiring; each test under 10 s; the
  reference regression passes 7 of 7.
- **SC-R02G0806-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26) and the ambient loop player already exist and are reused; no new framework.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 of R02-G08-05 is unchanged); the sound
  choice is presentation state (saving it is R02-G08-07). Observability: the presenter keeps a feedback log
  (announcements and haptic kinds with their trigger) for tests and diagnostics, alongside the tier log.
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G0806-001, 005 |
| Accessibility (pieces named by share and faces, directions in words) | FR-R02G0806-001, 002, 005 |
| Reduce flashing | FR-R02G0806-004 |
| Audio | FR-R02G0806-006 |
| Haptics | FR-R02G0806-003 |
| No Stage One breakage | FR-R02G0806-007 |

## Negative Requirements / Excluded scope

- No saving of progress to disk (R02-G08-07); no new levels; no purchases, ads or tracking; no recorded audio; no device
  run before ImplementationLock-100; no availability before X-R02-G08.
