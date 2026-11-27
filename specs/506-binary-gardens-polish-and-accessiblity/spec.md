# Feature Specification: R02-G21-06 — Binary Gardens: polish and accessibility

**Feature Branch**: `506-binary-gardens-polish-and-accessiblity` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-06 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2106-###,
SC-R02G2106-###, T-R02G2106-###

**Input**: User description: the archived R02-G21-06 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Ship clear native overlays, accessibility, reduce-flashing, audio and haptics" for Binary Gardens, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/506-binary-gardens-polish-and-accessiblity` (the archived spelling of the
  directory is kept); FR-R02G2106-###, SC-R02G2106-###, T-R02G2106-###.
- **Packaging (ADR-0009):** polish and accessibility live in the experience `r02-g21.binary-gardens` (a registered
  candidate since R02-G21-03) inside the one app; no app target, bundle identifier, XcodeGen scheme or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, "content count 81" (the 100 certified
  levels of R02-G21-02 stand) and the paths `Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore` (the
  experience lives in `Packages/ExperiencesRound02/BinaryGardens`); entitlement is the shared purchase controller's,
  tier free. **Device-only items:** sound, haptics and VoiceOver on D1/D2/D3, recorded as `{device}` items for after
  ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F26 (input and accessibility contract, shared feedback route), the shared ambient loop
  player and one-shot sound player, and the kernel, content, adapter, renderer of R02-G21-01 … 03 in code.
- **Prerequisites not yet in code (planned, specified and tasked, 2026-11-27):** R02-G21-04 (feature 504: the gesture
  controller, the panel's direct ring, luminosity, tilt and phase choices, "Inspect" and "Reset view", the presenter's
  refusal log) and R02-G21-05 (feature 505: hints, the state-derived tutorial with `tutorial.dismiss`, the failure
  explanation, progress and stars, `level.select`, `mode.campaign`, `mode.practice`, `mode.daily`, the codes
  `r02-g21.locked` and `r02-g21.date`, snapshot schema 2 and digest domain v2). This feature builds on them and is
  implemented after both gates are recorded; where a requirement below names their parts, it names them as
  prerequisites.
- **Model:** feature 496 (Mushroom Weather's polish and accessibility, itself modelled on feature 486), adapted to the
  twin stars on their rings with their phases and luminosities, the tilt of the orbit plane, the worlds' light gauges
  over the 48 ticks of a cycle, the run of the light and the frozen, scorched, unstable, wilted and bleached failures.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
496's answers where the games agree. Facts checked in committed code and specs (read-only, 2026-11-27):

- **Shared facilities:** the shared route `ExperienceFeedback` (VisualCoreExperienceHost: `haptic(_:)`,
  `announce(_:kind:)`, `flush()`), `AnnouncementKind` (`rejection`, `outcome`, `level`, `state`) and `HapticKind`
  (`selection`, `success`, `warning`, `error`, plus impacts) of VisualCoreSimulation's accessibility plans, whose
  announcement planner posts at most one announcement per 0.5 s and merges a burst to its newest; `AmbientLoopPlayer`
  (VisualCoreAudio, ambient session category, no input, `isEnabled`, `play()`, `stop()` on interruption, media-services
  reset and backgrounding) playing one fixed `AmbientLoopRecipe` (VisualCoreAudioDSP: 48 kHz, 4 … 16 s, 1 … 6
  partials, gain 0 … 0.3); and `SoundEffectPlayer` (VisualCoreAudio, at most 4 voices, ambient category) for one-shot
  sounds. Feature 496 uses exactly these (`MushroomWeatherFeedbackPlan`, `MushroomWeatherLights`,
  `MushroomWeatherSoundRecipe`, `MushroomWeatherSound`).
- **Kernel and adapter (features 501 … 503):** the adapter declares `star.ring [star, index]`, `star.phase [star,
  step]`, `star.luminosity [star, index]`, `orbit.tilt [step]` (each sets one control and spends 1 action),
  `light.run` (spends none and always ends the level, won or failed), `play.undo`, `play.redo` (undo works in playing
  and failed plays; a won run is final), `level.next` and `clock.show [tick]` (presentation, ticks 1 … 48, 48 at an
  opening); stages `loading`, `tutorial`, `playing`, `paused`, `won`, `failed`, `result`; refusal codes
  `r02-g21.level`, `action`, `budget`, `stage`, `stale`, `generation`, `newer-schema`, `malformed`, `witness` (kernel)
  and `r02-g21.not-whole`, `r02-g21.tick` (adapter), reported by the engine as `action.rule.<code>`. The level gives
  words: `starDescription` ("star 1 on ring 3, 12 units, phase 9, luminosity 24"), `worldTickDescription` ("world 2 at
  tick 17: 41 250 milliflux, comfortable, band 30 000 … 52 000"), `worldDescription`, `failureDescription` and
  `progressDescription` (both stars, the tilt, every world, the closest approach, "running now would win" or "running
  now would fail: …", "a actions left"). A star has `ringAdjustable`, `phaseAdjustable` and `luminosityAdjustable`; the
  tilt is locked when T_max = 0. `BinaryGardensPuzzle(level:).moves(in:)` lists the legal arrangement moves (none with
  the budget spent).
- **Presenter, panel and scene (feature 503):** the presenter takes `reduceMotion` and `reduceFlashing` at creation;
  the scene passes `u_motion` = `BinaryGardensShaders.motion(reduceMotion:)` (0 under Reduce Motion), so the corona
  rays' reach (0.25 pulses per second) and the pollen motes (0.08 loops per second) stop under Reduce Motion only —
  Reduce Flashing does not still them today; `u_won` is 0 or 1 from `snapshot.isWon` (no easing), and in the unlit
  fallback the won colours switch at a won light of 0.5; the glow gain is `glowGain(for:)` (level-0 1.5, level-1 1.0,
  level-2 0, no glow shells) capped in the shader by `u_glowLimit` = `glowLimit(reduceFlashing:)` (1.5 normally, 0.5
  under Reduce Flashing); a world's glow shell has factor 1 when it is comfortable at the shown tick, else 0, so the
  shells switch at once when the shown tick changes; no position moves by time; a memory warning releases the GPU
  objects. The panel is a vertical `ScrollView` with system text styles (headline, subheadline, footnote), a segmented
  star picker, rows of − and + buttons for ring, phase, luminosity, tilt and the shown tick, Run, Undo, Redo and Next
  level, each in a horizontal row that does not wrap; the tilt and tick readouts carry an identifier but no label or
  value, and Undo, Redo and Next level have labels but no values. A refusal is shown as "That change was refused: …"
  with lower-case words from `BinaryGardensMirror.refusalText(code:)`. There is no announcement, haptic, sound, feedback
  log or sound choice in the experience today.

- Q: What exactly is announced, and with which kind? → A: after an accepted action (`state`), the change then the
  progress: "Star n moved to ring r (ρ units)." / "Star n shifted to phase p." / "Star n's luminosity set to L." / "Tilt
  set to t of T steps."; undo and redo "Undone." / "Redone."; each followed by " w of n worlds keep their light,
  running now would win (or fail), a actions left." ("1 action left" singular; stars and rings counted from 1, ρ the
  ring's radius and L the luminosity in units as the level words them; a world keeps its light when, in the play's
  report of the current arrangement, its longest lethal run is at most the level's lethal tolerance, its comfortable
  window reaches its required window and its total light lies inside its bloom band); a win (`outcome`): "Every world
  kept its light and bloomed. Level won spending a actions, k of 3 stars." (without the stars in practice; a and k by
  feature 505's progress rules); a failure (`outcome`): the failure explanation of feature 505; a level or mode change
  (`level`): "Level n, band b, <campaign|practice|daily>." with the tutorial instruction when shown; a refusal
  (`rejection`) in words: `r02-g21.locked` "That level is not open yet.", `r02-g21.date` "That date cannot be used.",
  `r02-g21.action` "That ring, phase, brightness or tilt change cannot be made (locked, unchanged, off the phase grid or
  too close to the other star), or there is nothing to undo or redo.", `r02-g21.budget` "No actions are left: run the
  light or undo a change.", `r02-g21.stage` "The level has ended.", `r02-g21.stale` "The play changed before the action
  arrived.", `r02-g21.level` and `r02-g21.generation` "That level could not be made.", `r02-g21.not-whole` "That value
  must be a whole number.", `r02-g21.tick` "Only ticks 1 to 48 can be shown.", any other code "That action was
  refused." (the engine's `action.rule.` prefix read as the bare code). A revealed hint is announced (`state`) with its
  text. Changing the panel's selected star or phase target, previews, the shown tick, an inspection, the view,
  dismissing the tutorial and the Sound toggle are not announced (the controls speak their own values). Texts are a
  pure function of the old and new core (and the refusal code), so tests compare them exactly; the panel shows the same
  refusal sentence in place of today's "That change was refused: …" line. Impact: FR-R02G2106-002; SC-R02G2106-002.
- Q: Which haptics play, and how are bursts handled? → A: `selection` for an accepted ring, phase, luminosity or tilt
  action, undo or redo; `success` for a won run; `warning` for a failed run; `error` for a refusal; changing the
  selected star, previews, the shown tick, inspections, the view and level or mode changes play none. The run plays
  only its outcome. The shared planners' intervals apply. Impact: FR-R02G2106-003; SC-R02G2106-002.
- Q: How are fades done and measured under Reduce Flashing, and what stays still? → A: as feature 496, plus the
  worlds' glow shells: the presenter keeps eased light levels for the glow (0.7 while playing, 1 once won, 0.35 once
  failed; a failure counts only once the run has failed, never the report's predicted failure), the won look (1 once
  won, else 0) and each world's bloom (1 when the world is comfortable at the shown tick or the level is won, else 0),
  each easing toward its target by the frame clock's elapsed time between drawn frames (0.15 s normally, 0.45 s under
  Reduce Flashing, linear; under Reduce Flashing a fade that has started finishes before it may turn back); the scene
  draws the eased levels (the glow gain times the glow level, each world's shell factor its bloom level — the factor is vertex data of the glow mesh, so the mesh is rebuilt
  when a bloom level crosses a 1/32 step —, the won
  uniform the won level, and in the fallback the not-won and won colours blended by the won level, rebuilt when the
  level moves by a tenth or more); the state and digest never see them. The stars, rings, phases, luminosity pips, tilt
  dial, gauges, trails and the worlds' band tints change only with the player's actions and the shown tick and are not
  faded; the pollen motes a won run adds around the worlds appear with the outcome, like the band tints. The corona rays and pollen motes move at under 1 cycle per second normally; under Reduce Motion or Reduce
  Flashing their time is held at 0, so the system is still between actions. The measure: sampling the drawn levels
  every 1/60 s through a scripted win and adversarial flicker (a ring change undone and redone every frame, a failed
  run undone and redone every frame, the shown tick stepped back and forth every frame, level changes), no eased
  element crosses half its range more than 3 times per second, and every complete one-way fade of more than half the
  range takes at least 0.4 s under Reduce Flashing. Impact: FR-R02G2106-004; SC-R02G2106-003.
- Q: Where does the sound choice live, and what are the audition and ambient recipes? → A: a Sound toggle in the panel,
  off by default, held by the presenter (presentation only; saving it is R02-G21-07). The selected star's tone is
  220 Hz × 2^(n / 12) with n = 2 × (7 − its ring index, clamped to 0 … 7) (0, 2 … 14: outer rings sound lower); a star
  that can change now (the play is playing and the puzzle's legal moves from the current arrangement and actions spent
  include a ring, phase or luminosity move of that star) sounds its tone and the tone × 3/2 at gain 0.04 each, a clean
  fifth; one that cannot sounds its tone with a second partial 3 Hz above it at gain 0.04 each, so it beats audibly;
  0.6 s with a linear decay to silence; played once per change of the panel's selected star and once after an accepted
  ring change of the selected star, a new one replacing the last; never for previews. The audition is a pure function
  of (ring index, can change). The ambient recipe is a pure function of the worlds keeping their light, the worlds, the
  stars' luminosities, the actions left as a share of the budget and the stage: a root at 110 Hz times (1, 9/8, 5/4,
  4/3) for more than three quarters of the actions left, more than half, more than a quarter, or less (integer
  comparisons 4·left > 3·budget, 2·left > budget, 4·left > budget); one partial per quarter of the worlds keeping their
  light (⌊4 × w / n⌋, up to four), at the root times (5/4, 3/2, 2, 5/2)[q − 1] for q = 1 … quarters, each with the base
  amplitude; the root alone when fewer than a quarter keep it; a brightness partial at the root × 3 with the base
  amplitude × (i₁ + i₂) / (2 × (m − 1)) when the level has m > 1 luminosity levels and the stars' luminosity indices i₁
  and i₂ sum above 0; a won play adds the octave (merged with the equal partial, so at most 6 partials) and swells twice
  per loop; a failed play halves every amplitude and the gain; the loop's length is the longest the shared player
  accepts at which every partial has a whole number of cycles (tested). The presenter rebuilds the loop only when the
  level opens, or an action, undo, redo or the run changes the quarters, the root step, the brightness partial or the
  stage, or the toggle turns on, never per frame. Sound plays exactly while the choice is on, the controls are on screen
  and the scene is active. Impact: FR-R02G2106-006; SC-R02G2106-004.
- Q: What do Larger Text and Increase Contrast require of the panel? → A: the panel scrolls vertically, uses system
  text styles that grow with Dynamic Type up to the largest accessibility size, wraps rather than truncates labels and
  uses system colours, so Increase Contrast applies; button rows wrap into a column at accessibility sizes; the panel's
  star, ring, phase, luminosity, tilt and shown tick are accessibility-adjustable elements with their labels and values
  in words ("star n of 2", "ring r of R, ρ units", "phase p of 47, step g", "level l of m, luminosity L", "tilt t of T
  steps", "tick t of 48"; ", locked" added when the level locks that control); incrementing or decrementing the star
  or the shown tick changes only the presentation, while the ring, phase, luminosity and tilt send one action each (the
  neighbouring ring, a phase step g, the neighbouring luminosity level, a tilt step), and a refused one is announced;
  a summary element reads "a actions left. <the progress in words>. Selected: <the selected star in words>. Shown: tick t of 48:
  <every world at the shown tick in words>. Level: <the level in words>."; on iPad the panel keeps a readable width (at
  most 520 points). Impact: FR-R02G2106-001, 005; SC-R02G2106-001.
- Q: What does a tier-safe presentation require? → A: every host tier (level-0, level-1, level-2) and the unlit
  fallback give the same announcements, haptics, sound, panel and comfort behaviour; the tiers keep changing only
  tessellation, corona rays, trails, motes and glow shells; at level-2 (no glow shells) and in the fallback the eased
  won level still drives the won look; the Reduce Flashing glow cap and the held time apply at every tier; a tier
  change or a memory warning resets no eased level, feedback log or sound state. Impact: FR-R02G2106-007;
  SC-R02G2106-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Binary Gardens with VoiceOver (Priority: P1) 🎯

A blind or low-vision player can learn the level's state (both stars with their rings, phases and luminosities, the
tilt, each world's light against its comfortable band at the shown tick, its comfortable window, lethal run and total
light against its bounds, whether running now would win and why not, the panel's selected star, the shown tick, the
actions left), move the stars between rings, shift their phases, change their brightness, tilt the orbit plane, step
the shown tick, run the light, undo and redo, ask for hints, read failures, choose levels and modes, and hear every
change and result, without seeing the system. Stars, rings, worlds and ticks are named by number and every band in
words, so no colour or shape needs to be seen.

**Why this priority**: an experience that cannot be played with VoiceOver is not shippable in the one app.

**Independent Test**: every native control has a label and value; the panel's star, ring, phase, luminosity, tilt and
shown tick are adjustable; every accepted ring, phase, luminosity and tilt action, run, undo, redo, refusal, win,
failure and level change produces one announcement through the shared route while VoiceOver runs.

**Acceptance Scenarios**:

1. **Given** VoiceOver runs, **When** the player moves a star to another ring or tilts the orbit plane, **Then** it is
   applied and one announcement names the change, the worlds keeping their light and the actions left.
2. **Given** a run fails, **When** the level fails, **Then** the failure explanation is announced as an outcome.
3. **Given** VoiceOver runs, **When** an action is refused, **Then** the refusal is announced in words and the panel
   shows the same sentence.
4. **Given** VoiceOver runs, **When** the player increments the shown tick, **Then** the tick element speaks its new
   value and no announcement is posted.

### User Story 2 - Comfort settings are honoured (Priority: P1)

Players who choose Reduce Motion, Reduce Flashing, Larger Text or Increase Contrast get a still system, no flashing,
text that grows and stays readable, and controls that stay usable.

**Why this priority**: photosensitivity and motion sensitivity are safety concerns; two bright suns with pulsing
coronas, worlds that bloom all at once on a win and glow shells that switch with the shown tick are bright and moving
subjects.

**Independent Test**: with Reduce Flashing, no eased element changes brightness more than three times a second and the
glow stays capped; with Reduce Motion, two frames of the same state at different times are identical; the panel lays
out at the largest accessibility text size without clipping the controls.

**Acceptance Scenarios**:

1. **Given** Reduce Flashing, **When** the level is won or fails, **Then** every change of the glow and of the won look
   is a fade of at least 0.4 s, not a flash (what the player's action changes — the stars, the rings, the pips, the
   dial, the gauges, the band tints — appears with the action).
2. **Given** Reduce Flashing, **When** the shown tick is stepped back and forth every frame, **Then** no world's glow
   shell crosses half its range more than 3 times per second.
3. **Given** Reduce Motion or Reduce Flashing, **When** two frames of the same state are drawn at different times
   (after any fade has finished), **Then** they are identical.

### User Story 3 - Gentle sound and haptics (Priority: P2)

Each accepted ring, phase, luminosity or tilt action, undo or redo gives a light selection haptic; a win a success
haptic; a failure a warning; a refused action an error haptic; all subject to the person's haptics switch. Choosing the
panel's star plays a short tone made in code from that star's ring and whether it can change (the audition), and an
optional ambient sound, made in code from the worlds keeping their light, the stars' brightness, the actions left and
the stage, plays while the experience is on screen and the sound choice is on, and falls silent off screen.

**Why this priority**: feedback helps, but the game must work silently.

**Independent Test**: scripted actions produce the planned haptic kinds through a recording sink; the audition and
ambient recipes are pure functions of the state they are made from; sound plays only while wanted, on screen and
active.

### User Story 4 - The same experience at every quality tier (Priority: P2)

A player on a device the quality controller moves to a lower tier, or whose shader programs fail and fall back to the
unlit path, still gets every announcement, haptic, sound, panel control and comfort setting.

**Why this priority**: the one app runs on every supported device; accessibility may not depend on the GPU.

**Independent Test**: the same scripted session at level-0, level-1, level-2 and in the fallback yields equal feedback
logs, equal sound decisions and, under Reduce Flashing, the same fade bounds.

### Edge Cases

- **Many quick actions (rapid ring or phase steps, undos and redos):** haptics and announcements obey the shared rate
  limits (a burst of announcements posts its newest); an outcome is never lost.
- **A run, which always ends the level:** only the outcome (win or failure) is announced and felt; a run with no
  action left is still allowed and announced by its outcome.
- **Undo out of a failed play:** the play returns to playing and is a `state` announcement with the progress.
- **Undo or redo of a won play:** refused (a won run is final) and announced in words.
- **A locked control (ring, phase, luminosity or tilt):** its element says "locked"; an attempt is refused and
  announced.
- **Changing the selected star, previews, the shown tick, an inspection and the view:** not announced (the adjustable
  controls speak their own values); changing the selected star plays its audition only when the sound choice is on.
- **A selected star that cannot change (both of its controls locked, no legal move, no action left or the level
  ended):** its audition is audibly different, never silence.
- **A shown tick outside 1 … 48 sent directly:** refused `r02-g21.tick`, announced in words, nothing changes.
- **VoiceOver off:** no announcement is made; haptics still follow the switch.
- **Audio session unavailable or interrupted:** no sound starts or it stops; the game is unaffected and the sound choice
  stays on.
- **Sound choice off:** no player is made and no audio session is touched.
- **Largest text on the smallest iPhone:** the panel scrolls rather than clipping controls.
- **Tier change or memory warning mid-fade:** the fade continues from its current level; nothing is announced.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2106-001**: Every native control (star, ring − and +, phase − and +, luminosity − and +, tilt − and +, tick
  − and +, run, undo, redo, next level, sound; and, from the prerequisites, the ring, luminosity and tilt choices, the
  phase target and Set phase, Inspect and Reset view of feature 504, and the hint, dismiss, level picker and mode
  buttons of feature 505) MUST have an accessibility label and value; a summary element MUST read the actions left, the
  progress in words (whether running now would win), the selected star, every world at the shown tick and the level;
  and the panel's star, ring, phase, luminosity, tilt and shown tick MUST be adjustable with VoiceOver, naming a locked
  control as locked.
- **FR-R02G2106-002**: Every accepted ring, phase, luminosity and tilt action, undo and redo MUST be announced with what
  changed, the worlds keeping their light and the actions left (kind `state`); wins and failures (with the explanation)
  as `outcome`; level and mode changes as `level`; refusals in words as `rejection`, through the shared route, with the
  exact texts of the clarifications; the panel MUST show the same refusal sentence.
- **FR-R02G2106-003**: Haptics MUST map selection → accepted ring, phase, luminosity or tilt action, undo or redo,
  success → win, warning → failure, error → refused action, through the shared route and the person's switch; they
  never change state.
- **FR-R02G2106-004**: Reduce Flashing MUST cap the glow and turn every brightness change of the glow, of each world's
  glow shell and of the won look into fades of at least 0.4 s, with every periodic motion below 3 cycles per second;
  Reduce Motion and Reduce Flashing MUST keep the system still between actions (no pulsing coronas or drifting motes);
  neither changes the state or its digest.
- **FR-R02G2106-005**: The panel MUST support Dynamic Type up to the largest accessibility size and Increase Contrast on
  iPhone and iPad, scrolling instead of clipping, wrapping button rows into a column at accessibility sizes and keeping
  at most 520 points of width on iPad.
- **FR-R02G2106-006**: A star audition and an optional ambient sound MUST be synthesized in code — the audition from the
  panel's selected star (its ring and whether it can change now), the ambient sound from the worlds keeping their
  light, the stars' luminosities, the actions left and the stage — play only while wanted, on screen and active, and
  never touch audio when off.
- **FR-R02G2106-007**: Announcements, haptics, sound, the panel and the comfort behaviour MUST be identical at every
  host tier and in the unlit fallback; the tiers MUST keep changing only tessellation, corona rays, trails, motes and
  glow shells, and a tier change or memory warning MUST NOT reset an eased level, the feedback log or the sound state.
- **FR-R02G2106-008**: The presenter MUST keep a feedback log (each announcement's kind and text and each haptic's kind
  with its trigger), alongside the tier log and feature 504's refusal log, for tests and diagnostics; nothing leaves
  the device.
- **FR-R02G2106-009**: Existing tests pass except the assertions this feature deliberately changes (the refusal words
  of `refusalText(code:)` and any R02-G21-04 or R02-G21-05 test asserting the former refusal line, and
  `BinaryGardensRenderTests.aWonLevelBloomsEveryWorld`, which draws one settling frame before its checked frame because
  the won look now fades in; no committed test asserts the motion under Reduce Flashing alone), updated in place and named in the tasks; no state, digest or
  snapshot schema change; new public names documented with `///`; the reference regression passes.

### Key Entities

- **Announcement plan**: kind and text for each state change or refusal.
- **Haptic plan**: kind for each outcome of an action.
- **Light levels**: the glow, each world's bloom and the won look, eased by the frame clock's elapsed time.
- **Audition recipe**: partials (frequencies, gains, decay) derived from the selected star's ring and whether it can
  change.
- **Ambient recipe**: partials (frequencies, gains, swell) derived from the worlds keeping their light, the stars'
  luminosities, the actions left and the stage.
- **Feedback log**: the announcements and haptics posted, in order, with their triggers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2106-001**: 100 % of native controls expose a label and value; level 1 is won within its budget using only
  the operations VoiceOver performs on the panel's native controls (the adjustable star, ring, phase, luminosity, tilt
  and tick increments and decrements, feature 504's direct choices and Run), with every step announced.
- **SC-R02G2106-002**: For scripted sequences of ring, phase, luminosity and tilt actions, undos, redos, refusals of
  every listed code, wins and failures of each of the five causes, the recorded announcements and haptics equal the
  plan exactly (kinds and texts).
- **SC-R02G2106-003**: With Reduce Flashing, no eased element crosses half its brightness range more than 3 times per
  second over a scripted win and the adversarial flicker of the clarifications, and every complete one-way fade of
  more than half the range takes at least 0.4 s; with Reduce Motion or Reduce Flashing, two frames of the same state at
  different times are identical.
- **SC-R02G2106-004**: The audition and ambient recipes are identical for equal inputs and differ when an input differs;
  every ambient recipe the catalog's 100 levels can reach in their start arrangement, their certified arrangement and
  the won and failed stages is a valid recipe of the shared player (at most 6 partials, gain at most 0.3, 4 … 16 s,
  whole cycles); sound plays exactly while wanted, on screen and active (state-table test).
- **SC-R02G2106-005**: The same scripted session at the three tiers and in the fallback yields equal feedback logs and
  sound decisions; existing tests pass unchanged except where this feature changes assertions on purpose; each new
  test runs under 10 s; the reference regression passes 7 of 7.
- **SC-R02G2106-006** {device}: after ImplementationLock-100, sound, haptics and VoiceOver are checked on D1/D2/D3.

## Assumptions

- The shared feedback route (R02-F26), the ambient loop player and the one-shot sound player already exist and are
  reused; no new framework.
- Features 504 and 505 are implemented and their gates recorded before this feature's implementation; their controls,
  hints, tutorial, progress, modes and refusal codes are taken as specified there.
- Real-hardware observation of sound, haptics and VoiceOver happens in D1–D3 after ImplementationLock-100.
- All text is original; no third-party sounds or images; the sound is synthesized.
- Schema migration: none; this feature adds no stored state (snapshot schema 2 and digest domain v2 of R02-G21-05 are
  unchanged); the sound choice is presentation state (saving it is R02-G21-07). Observability: the feedback log,
  alongside the tier log and the refusal log.
- Error handling: a refused action changes nothing and is explained in words; an unavailable audio session leaves the
  game silent and playable; a failed shader program keeps every feedback path (the fallback).
- Copyright and originality: the design is the project's own archived design; the code and texts are original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Clear native overlays | FR-R02G2106-001, 005 |
| Accessibility (stars, rings, worlds and ticks by number; bands in words) | FR-R02G2106-001, 002, 005 |
| Reduce flashing (and reduce motion) | FR-R02G2106-004 |
| Audio (audition and ambient sound) | FR-R02G2106-006 |
| Haptics | FR-R02G2106-003 |
| Tier-safe presentation | FR-R02G2106-007 |
| Observability | FR-R02G2106-008 |
| No Stage One breakage | FR-R02G2106-009 |

## Negative Requirements / Excluded scope

- No saving of progress or of the sound choice to disk (R02-G21-07); no new levels, gestures or teaching beyond
  features 504 and 505; no purchases, ads or tracking; no recorded audio; no system accessibility audits before device
  testing; no device run before ImplementationLock-100; no availability before X-R02-G21.
