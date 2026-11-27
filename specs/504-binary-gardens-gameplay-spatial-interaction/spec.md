# Feature Specification: R02-G21-04 — Binary Gardens: gameplay spatial interaction

**Feature Branch**: `504-binary-gardens-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-04 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2104-###,
SC-R02G2104-###, T-R02G2104-###

**Input**: User description: the archived R02-G21-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Binary Gardens (controls: "drag star distance
rings, tilt orbit plane, inspect each miniature world"), with the canonical overrides of ADR-0009 and Auto-Creator.md
sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/504-binary-gardens-gameplay-spatial-interaction`; FR-R02G2104-###,
  SC-R02G2104-###, T-R02G2104-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g21.binary-gardens` (a registered candidate from
  R02-G21-03) inside the one app; the source's `Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore` paths
  are superseded by `Packages/ExperiencesRound02/BinaryGardens` (Core, Experience and their tests).
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the prior-round device prerequisites
  (entitlement comes from the shared purchase controller, tier free). The source's "content count 81" is a milestone
  figure; the 100 certified levels of R02-G21-02 stand. **Device-only items:** touch feel and latency on D1/D2/D3,
  recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter, scene
  snapshot, geometry and camera of R02-G21-01 … 03.
- **Model:** feature 494 (Mushroom Weather's gameplay spatial interaction: `MushroomWeatherGestureController`,
  `MushroomWeatherPicker`, `MushroomWeatherViewOrbit` and the presenter wiring), itself modelled on feature 484
  (Microscopic Aurora), adapted to stars dragged across their rings and along their orbit, luminosity pips, the tilt
  dial, worlds inspected and gauges scrubbed.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
494's answers where the games agree. Facts checked (read-only, 2026-11-27): the host's `PointerEvent` (id, phase
began/moved/ended/cancelled, location in view points with the origin top-left, monotonic timestamp in seconds); feature
494's constants as implemented (tap below 10 points and 0.5 s, drag from 16 points, double tap within 0.35 s and 22
points, orbit 90° per view width and 60° per view height, yaw ±60°, pitch −20° … +35°, marker allowance 12 points,
band 14 points, reach 24 points, step travel 40 points) and its controller, picker and orbit. The Binary Gardens kernel
(feature 501, with feature 502's phase step): a star at ring radius ρ, phase θ and tilt τ stands at
(ρ·C[θ]·1024, ρ·S[θ]·C[τ], ρ·S[θ]·S[τ]) at scale 2²⁰; both stars move at the level's star speed ω (1 … 3 steps per
tick), so a star of phase θ stands at table step (θ + ω·t) mod 48 at tick t; the actions `ring(star:index:)`,
`phase(star:step:)`, `luminosity(star:index:)` and `tilt(step:)` each spend one action and are refused, without any
change, out of stage, stale, out of range, off the phase grid (a phase not a multiple of the phase step g), locked
(the star's `ringAdjustable`, `phaseAdjustable`, `luminosityAdjustable` flags; tilt locked when T_max = 0), unchanged,
breaking the minimum separation, or with no action left (`r02-g21.stage`, `.stale`, `.action`, `.budget`); the run
spends nothing and ends the level; undo works from playing and failed, redo from playing; the level gives words for
every star (`starDescription`), world (`worldDescription`) and failure (`failureDescription`); a witness is at most
`budget` arrangement actions, each one ring, phase, luminosity or tilt action naming its target value directly, then
the run. Feature 503 (R02-G21-03, ready, being implemented while this feature is specified, as the faster-gates rule
allows) specifies the scene: kernel point (x, y, z) drawn at k·(x, y, z)/2²⁰ with k = 0.95/R; the tilt dial (T_max + 1
pips from (−1.15, 1.08, 0) to the right in steps of 0.05); per ring radius a dashed 48-gon of radius k·ρ in the orbit
plane at the current tilt; per world a 48-gon of radius k·a in the base plane; the bodies sorted back to front from the
eye (ties: worlds first, then index), a world a cube-sphere of radius 0.07, a star a disc of radius
0.05 + 0.012·(luminosity index) with one pip per luminosity level beneath it, filled up to its current level; one gauge
row per world from y = −1.2 down in steps of 0.1 (plate x −0.95 … 1.22, 48 tick cells from x −0.9 to 0.9, the bloom
meter x 0.97 … 1.2, a marker over the shown tick); the actions bars below; painter's order with no depth buffer; the
authored camera eye (0, −2.0, 3.2) looking at (0, −0.35, 0) fitted to the box x −1.3 … 1.3, y −1.85 … 1.15,
z −0.85 … 0.85 with a margin of 0.06 per side (`fitMargin`, at least 5 %) for aspect 0.4 … 2.5. Its adapter declares `star.ring [star, index]`, `star.phase
[star, step]`, `star.luminosity [star, index]`, `orbit.tilt [step]`, `light.run`, `play.undo`, `play.redo`,
`level.next` and `clock.show [tick]` (declared 0 … 60, of which 1 … 48 are shown and 0 and 49 … 60 refused with `r02-g21.tick`; presentation only, 48
  at opening; gestures send only ticks 1 … 48). Its minimal panel (a star
picker, ring −/+, phase −/+ by g, luminosity −/+, tilt −/+, tick −/+, run, undo, redo, next level) spends one action
per − or + press, so a witness action that moves a ring, luminosity or tilt by more than one step, or a phase by more
than one grid step, would cost more than one action through it.

- Q: How is a touch picked? → A: at touch-down the targets are projected through the drawn camera (orbit included) into
  view points, and the target drawn last wins, in the reverse of the scene's painter's order: (1) the actions bars are
  empty space; (2) a gauge row j: the finger cast onto the plane z = 0 lies inside row j's plate rectangle as the scene
  draws it, the plates (0.09 tall at a 0.1 pitch) never overlapping, and the 0.01 gap between two plates being empty space; (3) the bodies front to back from the drawn eye (the reverse of the
  scene's back-to-front sort): for a star, first its luminosity pip row (within 12 points of the projected segment
  between its first and last pip centres, as the scene geometry gives them for the drawn eye, orbit included; pips are drawn after their star), then its
  disc (its projected radius grown by 12 points); for a world, its projected radius 0.07 grown by 12 points (a world's
  own pips are part of nothing); (4) a star ring (later ring indices first): within 12 points of its projected 48-gon;
  (5) the tilt dial (only when T_max > 0): within 12 points of the projected segment from its first to its last pip
  centre; (6) the system disc: the finger cast onto z = 0 within radius 0.95 of the origin; (7) anything else (world
  orbits, trails, backdrop, bars, glow) and unusable input (a non-finite point, a size that is not finite and positive)
  is empty space. Tap, drag and double-tap thresholds and the 12-point allowance are feature 494's. Impact:
  FR-R02G2104-009, 012; SC-R02G2104-001.
- Q: What do taps do? → A: a tap on a world inspects it (presentation only, in any stage): the world is marked by a
  marker-coloured ring and its gauge row by a bracket, and the description gives the kernel's words for it at the shown
  tick (its band, flux and each star's share, its longest comfortable window against W, its integral against the bloom
  band); a tap on the inspected world again, or "Inspect: none" in the panel, clears it. A tap on a star selects it in
  the panel and explains that a star is dragged along its orbit or across its rings. A tap on a ring explains that a
  star is dragged across the rings. A tap on a star's luminosity pip row sends `star.luminosity [star, i]` for the pip
  whose projected centre is nearest the finger (lower index on ties) when it differs from the current level. A tap on
  the tilt dial sends `orbit.tilt [step]` for the pip nearest the finger when it differs. A tap on a gauge row inspects
  world j and, when the cast x is at most 0.95 (not on the bloom meter), sends `clock.show [tick]` for the column under
  the finger (tick = clamp(⌊(x + 0.9) / (1.8 / 48)⌋ + 1, 1, 48)), in any stage. A tap on the system disc changes
  nothing (and breaks a double tap); two taps on empty space within 0.35 s and 22 points reset the view. Kernel actions
  (luminosity, tilt) are sent only while playing; on a won or failed play the description says the play is over (undo
  or next level), and in loading, tutorial or paused it says the level is not being played; locked controls and a level
  with a single luminosity level say so, sending nothing. Impact: FR-R02G2104-001, 005, 006, 007, 011.
- Q: How does a star drag choose between ring and phase, map the finger, and what is previewed? → A: a press on a star
  that travels 16 points or more while playing becomes a star drag. Its mode is decided once, at the move (or release)
  that starts it: with the star's projected tangent u at its drawn position (the projection of table step
  (θ + ω·t + 1) minus that of (θ + ω·t − 1) on the same ring and tilt, t the shown tick, 48 counting as 0), the travel
  vector's component along u against its component across u: along strictly greater is a phase drag, otherwise a ring
  drag; a projected tangent shorter than 0.5 points makes it a ring drag. When only one of the star's ring and phase is
  adjustable the drag takes that mode whatever the direction; when neither is, the drag explains that the star's ring
  and phase are fixed and sends nothing. A ring drag's target is the ring index whose point at the star's drawn table
  step (radius k·ρᵢ, same tilt) projects nearest the finger (lower index on ties); a phase drag's target is the grid
  phase p ∈ {0, g, 2g, …} whose drawn position at the shown tick, table step (p + ω·t) mod 48, projects nearest the
  finger (lower p on ties). A target equal to the current value is no change. The snapshot gains the level's star speed ω and each star's ring, phase and luminosity freedoms (copied from the
  level, presentation only), and a preview (the change
  as a kernel action, and the previewed report of that arrangement — computed by the kernel's own pure change rule and
  report, never a second implementation — with its verdict, or the kernel's refusal of the change: separation, no
  action left; none of it in the digest). The scene draws a ghost star (a dashed outline of the star's disc) at its
  target, the worlds and gauges from the previewed report, and the committed report's gauge cells as ghost outlines
  behind them (the ghost bands), so the change in each world's light is read cell by cell; a refused preview draws the
  ghost star in the broken colour, keeps the committed drawing and report and names the refusal in words (the broken ghost stands at the target for a
  ring or phase change, at the star with its previewed radius for a luminosity change, and at both stars' positions at
  the previewed tilt for a tilt change; the refusal is the kernel's, in the order the play gives it: the change rule's
  range, grid, locked or separation refusal first, then no action left). On release exactly one
  `star.ring [star, index]` or `star.phase [star, step]` is sent when the target is a change (a change the kernel will
  refuse is still sent once and its refusal shown with its reason code, as feature 494 does); otherwise nothing. A
  release outside playing, a cancel or a second finger clears the preview and sends nothing. Impact: FR-R02G2104-002,
  003, 004, 008, 011; SC-R02G2104-001, 003, 006.
- Q: How do the luminosity and tilt drags work, and how does the shown tick scrub? → A: a press on a star's luminosity
  pip row or on the tilt dial that travels 16 points or more while playing becomes a luminosity or tilt drag: the value
  under the finger is the touch-down value plus round(dx / 32) for the horizontal travel dx in view points (right
  raises; halves away from zero), clamped to 0 … (levels − 1) or 0 … T_max (the pips are too small on a phone to aim at
  one by one, so a drag counts travel, as feature 494's moon drag does); the drag previews like a star drag (the star
  disc and its pips at the previewed level, or the orbit plane, rings and stars at the previewed tilt, and the previewed
  report with its ghost bands); on release exactly one `star.luminosity [star, index]` or `orbit.tilt [step]` is sent
  when the value differs from the current one, otherwise nothing. A press on a gauge row scrubs from touch-down on in
  any stage: the tick under the finger is read at touch-down (nothing sent) and every later move sends `clock.show
  [tick]` whenever the tick differs from the last read (the cast x clamped to the cells, so dragging onto the bloom
  meter shows tick 48), never an undo step or a kernel action; a tap that already scrubbed sends nothing more. Two
  fingers as feature 494: a second finger cancels any one-finger gesture (nothing sent beyond clearing a preview) and
  orbits — yaw ±60° about the vertical axis through the authored box centre (90° per view width), pitch −20° … +35°
  (60° per view height); a third finger re-bases the midpoint; a double tap on empty space or "Reset view" returns to
  orbit (0, 0); the camera refits so the authored box stays inside the view with the authored margin of 0.06 per side (at least 5 %) at every orbit and aspect
  0.4 … 2.5 and the eye stays outside the box; meshes are rebuilt when the orbit changes, every part that faces the eye (star discs, pips, coronas, glow shells,
  ghost star, inspection ring) facing the drawn eye and the bodies sorted back to front from it. Impact: FR-R02G2104-005, 006,
  007, 010; SC-R02G2104-001, 002, 004.
- Q: How is it built and tested, and what does the panel gain? → A: a Core gesture controller
  (`BinaryGardensGestureController`) with a picker (`BinaryGardensPicker`) and a view orbit (`BinaryGardensViewOrbit`,
  with `camera(aspect:orbit:)` equal to the authored camera at orbit 0) takes pointer events with the view size, the
  drawn snapshot and the orbit and returns gesture actions (setRing, setPhase, setLuminosity, setTilt, showTick,
  inspectWorld, selectStar, preview, clearPreview, resetView, explain) and the orbit, with the constants of feature 494
  (tap 10 points and 0.5 s, drag 16 points, double tap 0.35 s and 22 points, orbit 90° and 60°, allowance 12 points)
  plus a step travel of 32 points and a tangent floor of 0.5 points; only event timestamps are read, never a clock. The
  geometry draws the ghost star, the ghost bands and the inspection marks; the presenter routes `pointer` through the
  controller and keeps the preview, the inspected world and the orbit in its mirror. Host tests feed 500 seeded taps,
  star drags (both modes), luminosity and tilt drags, world taps and scrubs on certified levels at several sizes and
  orbits against an independent pick written in the test; simulator tests send touches through the experience's
  pointer entry. The panel keeps its rows and gains direct choices that each send one action: for the selected star a
  ring choice (one entry per ring), a luminosity choice (one per level) and a phase target (a stepper by g, presentation
  only) with "Set phase"; a tilt choice (0 … T_max); an "Inspect" world choice; and "Reset view". A host test wins all
  100 certified levels through panel actions alone (each witness action as the selected star and its direct choice, then
  Run), each within its budget. Impact: FR-R02G2104-013, 014; SC-R02G2104-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag a star across its distance rings (Priority: P1) 🎯

A player presses a star and drags it outwards or inwards; the star's ghost jumps to the ring nearest the finger and the
light every world would receive is previewed — worlds and gauges show the new light while the current light stays as
ghost bands behind it. Lifting the finger commits the move as one action, undoable.

**Why this priority**: a star's distance is the game's main lever on flux.

**Independent Test**: scripted radial drags send exactly the ring change an independent pick predicts, or nothing, and
the previewed report equals the kernel's report of the changed arrangement.

**Acceptance Scenarios**:

1. **Given** a level while playing and a star whose ring is adjustable, **When** the player drags it across the rings
   and lifts nearest another ring, **Then** exactly one `star.ring [star, index]` for that ring is sent; lifted nearest
   its own ring, nothing is sent.
2. **Given** a star drag in progress, **When** the target ring changes, **Then** the preview shows the ghost star on that
   ring and the previewed report's light on every world and gauge, with the committed cells as ghost outlines, and the
   digest is unchanged.
3. **Given** a change that breaks the stars' minimum separation, **When** it is previewed, **Then** the ghost is drawn
   in the broken colour and the refusal is named; on release the action is sent once, refused, and its reason code
   shown.

### User Story 2 - Slide a star along its orbit (Priority: P1)

A player drags a star along its orbit; the ghost follows the finger from phase to phase on the level's phase grid,
previewed as in story 1; lifting commits one phase change.

**Why this priority**: the phase sets when the two suns meet and part, which the windows depend on.

**Independent Test**: scripted tangential drags send exactly the grid phase an independent computation predicts.

### User Story 3 - Brighten or dim a star (Priority: P1)

A player taps a pip beneath a star to choose its luminosity, or drags sideways along the pips, with the light
previewed; lifting commits one change to a different level, or nothing.

**Independent Test**: scripted pip taps and drags send exactly the level an independent computation predicts.

### User Story 4 - Tilt the orbit plane (Priority: P1)

A player taps a pip of the tilt dial, or drags sideways along it; the orbit plane, the rings and the stars tilt in the
preview with the light previewed; lifting commits one tilt change.

**Independent Test**: scripted dial taps and drags send exactly the tilt step an independent computation predicts.

### User Story 5 - Inspect a miniature world and scrub the cycle (Priority: P1)

A player taps a world to inspect it — it is marked, its gauge row bracketed, and its light, window and bloom are given
in words — and drags along a gauge row to move the shown tick through the cycle; the bodies, light and words follow and
nothing else changes.

**Independent Test**: scripted world taps inspect exactly the world an independent pick predicts; scripted scrubs show
exactly the ticks predicted; no kernel action is sent.

### User Story 6 - Look around the system and come back (Priority: P1)

A player orbits the system with two fingers within bounds and returns to the authored view by a double tap on empty
space or "Reset view"; the view never changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, the digest never
changes.

### User Story 7 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (star, ring, phase, luminosity, tilt,
tick, inspect, run, undo, redo, next level and "Reset view"), each arrangement change as one action, including winning
every certified level within its budget.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap is below 10 points and lifted within 0.5 s; a press lifted at 0.5 s or
  later without moving does nothing; two taps on empty space within 0.35 s and 22 points reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A star drag at an ambiguous angle:** the along and across components equal → ring drag; a star at a point where its
  projected tangent is shorter than 0.5 points → ring drag.
- **Locked controls:** a star whose ring is locked but phase adjustable always drags its phase (and the reverse); both
  locked, a locked luminosity, T_max = 0 (no dial drawn) or a single luminosity level: nothing is sent and the reason is
  given in words.
- **Phase grid g > 1:** only multiples of g are offered; the ghost snaps between them.
- **Bodies under each other** (a star in front of a world, a pip row over a ring): the target drawn last is picked, as
  drawn, by the scene's own back-to-front order.
- **A change the kernel refuses** (separation, no action left, the stage): previewed as refused, sent once on release,
  the refusal logged and shown with its reason code. A drag that changes nothing is never sent.
- **A finished play (won or failed) or a play not running (loading, tutorial, paused):** gestures send no kernel action
  (scrubbing and inspecting still work) and the description says why; orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** a preview clears and nothing is sent.
- **Opening, next level, reset and restore:** the preview and the inspected world clear, the orbit returns to the
  authored view and the shown tick to 48.
- **Very small or very wide views, 1 and 5 worlds, 2 and 8 rings, tilt 0 and 6:** picking, scrubbing and orbit work at
  every supported aspect; every projected value stays finite.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2104-001**: A tap on a world MUST inspect it in any stage (marked in the scene, its gauge row bracketed, the
  kernel's words for it at the shown tick in the description), presentation only; a second tap on it or "Inspect: none"
  MUST clear the inspection.
- **FR-R02G2104-002**: A ring drag that starts on a star while playing MUST preview the star on the ring nearest the
  finger with the previewed light report and, on release on another ring, send exactly one ring change for that star;
  any other release MUST send nothing.
- **FR-R02G2104-003**: A phase drag that starts on a star while playing MUST preview the star at the grid phase whose
  drawn position at the shown tick is nearest the finger and, on release at another phase, send exactly one phase
  change on the level's phase grid; any other release MUST send nothing.
- **FR-R02G2104-004**: A star drag's mode (ring or phase) MUST be decided once, deterministically, from the travel
  direction against the star's projected orbit tangent, overridden by which of the two is adjustable; a star whose ring
  and phase are both locked MUST send nothing and say why.
- **FR-R02G2104-005**: A tap on a star's luminosity pips or a sideways drag along them while playing MUST set (tap) or
  preview and, on release, set (drag) exactly one different luminosity level for that star, otherwise nothing.
- **FR-R02G2104-006**: A tap on the tilt dial or a sideways drag along it while playing MUST set (tap) or preview and,
  on release, set (drag) exactly one different tilt step, otherwise nothing.
- **FR-R02G2104-007**: A press on a gauge row MUST show the tick under the finger (presentation only) in any stage and
  send no kernel action; a tap on a row also inspects its world.
- **FR-R02G2104-008**: Previews MUST be presentation only: the previewed report and verdict computed by the kernel's own
  rules (ghost star at the target, worlds and gauges from the preview, the committed cells as ghost bands; a refusal
  named instead), never entering the digest, the snapshot's game state or the kernel.
- **FR-R02G2104-009**: Picking MUST be analytic and deterministic: each star's and world's projected disc, each star's
  pip row, each ring's projected 48-gon and the tilt dial grown by a fixed margin, each gauge row's cast plate, through
  the drawn camera (orbit included), the one drawn last first; the system disc is the cast disc of radius 0.95; anything
  else is empty space.
- **FR-R02G2104-010**: Two-finger orbit MUST stay within fixed yaw and pitch bounds, keep the scene inside the view with
  a margin of 0.06 per side (at least 5 %) at every aspect 0.4 … 2.5 and never enter the digest, the snapshot's game state or the kernel; a double
  tap on empty space or "Reset view" returns to the authored view.
- **FR-R02G2104-011**: Gestures outside playing, cancelled touches and second fingers MUST send no kernel action, and a
  gesture that does nothing for a stated reason (finished, not running, locked, single level, unchanged) MUST give that
  reason in words.
- **FR-R02G2104-012**: The gesture constants (tap 10 points and 0.5 s, drag 16 points, double tap 0.35 s and 22 points,
  orbit 90° per view width and 60° per view height, yaw ±60°, pitch −20° … +35°, allowance 12 points, step travel 32
  points, tangent floor 0.5 points) MUST be fixed public constants equal to feature 494's where shared, and only event
  timestamps MUST be read.
- **FR-R02G2104-013**: The panel MUST keep every action available without gestures, gain direct ring, luminosity, tilt
  and phase choices that each send one action, an "Inspect" world choice and "Reset view"; every certified witness MUST
  be replayable through panel actions within its budget.
- **FR-R02G2104-014**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code. Undo and redo stay the kernel's exact undo and redo through the panel.
- **FR-R02G2104-015**: No preview, ghost or inspection MUST be carried by hue alone (ghosts are dashed outlines, a
  refused ghost also named in words, the inspected world ringed and its row bracketed), and the presenter MUST expose
  its gesture state, preview, inspected world and orbit for diagnostics, with no telemetry leaving the device.
- **FR-R02G2104-016**: The snapshot schema MUST stay 1: the orbit, the preview, the inspected world and the shown tick
  are not saved, and opening, next level, reset and restore return them to their defaults.

### Key Entities

- **Gesture controller**: its state (idle, star press, ring drag, phase drag, pips press, luminosity drag, dial press,
  tilt drag, gauge press, scrub drag, world press, ring press, disc press, empty press, orbiting, cancelled), the touched
  target, the start and last points, the press time and the last tap's time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Snapshot additions**: the star speed ω and each star's ring, phase and luminosity freedoms, read by the controller
  at touch-down; never in the digest.
- **Preview**: the change as a kernel action (a star's ring, phase or luminosity, or the tilt) and the previewed report
  and verdict, or the kernel's refusal.
- **Inspection**: the inspected world, if any (presentation only).
- **Gesture action**: setRing, setPhase, setLuminosity, setTilt, showTick, inspectWorld, selectStar, preview,
  clearPreview, resetView, explain; the kernel ones map onto the declared adapter controls `star.ring`, `star.phase`,
  `star.luminosity`, `orbit.tilt`, and showTick onto `clock.show`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2104-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions, ticks and inspected worlds equal an independent computation.
- **SC-R02G2104-002**: Second fingers, cancels and gestures outside playing send no kernel action in every scripted
  case.
- **SC-R02G2104-003**: Orbit, previews, inspection and scrubbing never change the digest in every scripted case.
- **SC-R02G2104-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  margin of 0.06 per side (at least 5 %).
- **SC-R02G2104-005**: All 100 certified levels are won through panel actions alone, each within its budget.
- **SC-R02G2104-006**: For 200 scripted previews the previewed report and verdict (or refusal) equal the kernel's for the
  changed arrangement.
- **SC-R02G2104-007**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G2104-008** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G21-05; announcements, haptics, sound and full accessibility
  in R02-G21-06; persistence in R02-G21-07. The snapshot schema stays 1 here.
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 494 (and 484) so every round-two game feels the same.
- "Drag star distance rings" is read as dragging a star across its rings (with dragging along the orbit for its phase,
  the same press told apart by direction); "tilt orbit plane" as the tilt dial, tapped or dragged; "inspect each
  miniature world" as tapping a world (or its gauge row) to mark it and read its light, window and bloom in words, with
  no camera zoom (the fit guarantee stays one box). Running the cycle stays the panel's Run (a deliberate commitment,
  never a gesture side effect).
- The pip and plate positions picked are the ones the R02-G21-03 scene geometry draws; this feature reads them from the
  geometry rather than restating them.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Drag star distance rings | FR-R02G2104-002, 004, 008 |
| Phase along the orbit (the archived "phase twin stars" action) | FR-R02G2104-003, 004, 008 |
| Set luminosity | FR-R02G2104-005, 008 |
| Tilt orbit plane | FR-R02G2104-006, 008 |
| Inspect each miniature world | FR-R02G2104-001, 007 |
| Gesture-to-world actions (analytic picking, constants) | FR-R02G2104-009, 012 |
| Camera behavior (orbit, reset) | FR-R02G2104-010 |
| Undo, accessible panel, error handling | FR-R02G2104-011, 013, 014 |
| Accessibility, observability | FR-R02G2104-015 |
| Schema migration (none) | FR-R02G2104-016 |

## Negative Requirements / Excluded scope

- No new kernel action, no gesture that runs the cycle, no saved orbit, tick, preview or inspection, no camera zoom, no
  telemetry, no device run before ImplementationLock-100, no availability before X-R02-G21.
