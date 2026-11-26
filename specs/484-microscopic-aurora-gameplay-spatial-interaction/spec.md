# Feature Specification: R02-G19-04 — Microscopic Aurora: gameplay spatial interaction

**Feature Branch**: `484-microscopic-aurora-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G19-04 (migration ledger, game feature of experience R02-G19) · ID namespace FR-R02G1904-###,
SC-R02G1904-###, T-R02G1904-###

**Input**: User description: the archived R02-G19-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Microscopic Aurora (controls: "drag up to three
magnetic wells, scrub speed, tap freeze field"), with the canonical overrides of ADR-0009 and Auto-Creator.md sections 19
and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/484-microscopic-aurora-gameplay-spatial-interaction`; FR-R02G1904-###,
  SC-R02G1904-###, T-R02G1904-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g19.microscopic-aurora` (a registered candidate
  since R02-G19-03) inside the one app; the source's `Apps/MicroscopicAurora` and `Packages/GameModules` paths are
  superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 82" is a
  milestone figure; the 100 certified levels of R02-G19-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G19-01 … 03.
- **Model:** feature 474 (Apsides Workshop's gameplay spatial interaction) for the gesture controller, picker, orbit and
  panel, adapted to wells placed on sites.

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
474's answers where the games agree. Facts checked in code (read-only, 2026-11-26): the host's `PointerEvent` (id,
phase began/moved/ended/cancelled, location in view points with the origin top-left, timestamp); feature 474's
thresholds (tap below 10 points and 0.5 s, drag from 16 points, double tap within 0.35 s and 22 points, orbit 90° per
view width and 60° per view height, yaw ±60°, pitch −20° … +35°) and its `ApsidesWorkshopGestureController`,
`ApsidesWorkshopPicker` and `ApsidesWorkshopViewOrbit`. Microscopic Aurora's adapter declares `well.place [slot, row,
column, strength, sense]`, `well.remove [slot]`, `swim.play`, `play.undo`, `play.redo`, `level.next` and `clock.show
[tick]` (the last presentation only). The scene (`MicroscopicAuroraSceneGeometry`) maps dish units by s = 0.9 / 2816
about the dish centre in the plane z = 0, draws site rings (radius 0.35 cell), well spirals (radius 0.45 cell), gauges
at y −1.08 and −1.15 and the actions bars at y −1.25, from eye (0, −0.15, 3.4) towards (0, −0.15, 0), fitted to x
−1.0 … 1.0, y −1.35 … 1.0, in painter's order by kind (sites, then wells). The R02-G19-03 panel already places a well
with one action, so every certified witness (its placements on sites, then the play) fits its budget through the panel.

- Q: How is a touch picked? → A: at touch-down the targets are projected through the drawn camera (orbit included) into
  view points: a well is hit within its projected spiral radius grown by 12 points, a site within its projected ring
  radius grown by 12 points; of several hits the one drawn last wins (a well over its own site, then later slots). The
  swim scrubber, a track at y = −1.31 from x = −0.9 to 0.9 drawn below the actions bars with a mark at the shown tick, is
  hit within 14 points of its projected track. The dish field is the rest of the projected enclosure; anything else
  (gauges, bars, backdrop, fronds) is empty space. Tap, drag and double-tap thresholds are feature 474's. Impact:
  FR-R02G1904-006; SC-R02G1904-001.
- Q: What do taps do? → A: while playing, a tap on an empty site sends `well.place [slot, row, column, strength, sense]`
  with the first free slot and the panel's strength and sense; with every slot used it sends nothing and says so. A tap
  on a well selects its slot in the panel (presentation) and explains that wells are dragged. A tap on the scrubber
  sends `clock.show [tick]` with the tick nearest the finger along the track (round(fraction × ticks swum)) in any stage.
  A tap on the dish field toggles the freeze (presentation). A tap on empty space changes nothing and two such taps
  within 0.35 s and 22 points reset the view. On a won or failed play no kernel action is sent (the scrubber still shows
  ticks, the freeze still toggles) and the description says the play is over (undo or next level). Impact:
  FR-R02G1904-001, 003, 005, 008; SC-R02G1904-002.
- Q: How does a well drag map the finger to a change, and what is previewed? → A: a press on a well that moves 16 points
  or more while playing becomes a drag; the finger's target is the site whose projected centre is nearest the finger
  within 24 points (lower site index on ties); if that site is the well's own or another well holds it, no change;
  outside the projected enclosure the target is removal; otherwise no change. The snapshot gains a preview (the slot, the target
  and the previewed swim of the wells with that change: positions, density, lit cells, coverage, coherence and failure;
  none in the digest): unfrozen, the scene draws the previewed swim in place of the committed one and the dragged well
  as a ghost at its target; frozen, the committed swim stays and only the gauges show the previewed readings. On release
  exactly one `well.place [slot, row, column, strength, sense]` (moving the well, same strength and sense) or
  `well.remove [slot]` is sent when the target is a change; otherwise nothing. A release outside playing, a cancel or a
  second finger clears the preview and sends nothing. Impact: FR-R02G1904-002, 004, 008; SC-R02G1904-001, 003.
- Q: How do the scrubber and two fingers behave? → A: from touch-down on the scrubber, every move sets the tick nearest
  the finger along the track and sends `clock.show [tick]` (never an undo step, never a kernel action). Two fingers as
  feature 474: a second finger cancels any one-finger gesture (nothing sent) and orbits — yaw ±60° about the vertical
  axis through the authored box centre (90° per view width), pitch −20° … +35° (60° per view height); a third finger
  re-bases the midpoint; a double tap on empty space or "Reset view" returns to orbit (0, 0); the camera refits so the
  authored box stays inside the view with a 5 % margin at every orbit and aspect 0.4 … 2.5 and the eye stays outside the
  box; meshes are rebuilt when the orbit changes; orbit, the freeze and the preview are not saved (schema stays 1).
  Impact: FR-R02G1904-003, 007; SC-R02G1904-002, 004.
- Q: How is it built and tested, and what does the panel gain? → A: a Core gesture controller
  (`MicroscopicAuroraGestureController`) with a picker (`MicroscopicAuroraPicker`) and a view orbit
  (`MicroscopicAuroraViewOrbit`, with `camera(aspect:orbit:)` equal to the authored camera at orbit 0) takes pointer
  events with the view size, the drawn snapshot, the panel's strength and sense, the freeze and the orbit and returns
  gesture actions (place, move, remove, showTick, preview, clearPreview, toggleFreeze, selectSlot, resetView, explain)
  and the orbit; the geometry draws the scrubber and the preview; host tests feed 500 seeded taps, well drags and scrubs
  on certified levels at several orbits against an independent pick in the test; simulator tests send touches through
  the experience's pointer entry. The panel keeps its one-action placement and gains "Freeze" (the same toggle) and
  "Reset view"; a host test wins all 100 certified levels through panel actions alone (each witness placement as slot,
  site, strength and sense, then Play), each within its budget. Impact: FR-R02G1904-006, 009, 010; SC-R02G1904-001 …
  005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag a magnetic well between sites (Priority: P1) 🎯

A player taps an empty site to put a well there, presses a placed well and drags it to another site, or drags it off
the dish to take it away; while dragging, the swim the wells would give is previewed (ribbons, lit cells and gauges).
Lifting the finger commits the change as one action, undoable.

**Why this priority**: the wells are the game's only lever.

**Independent Test**: scripted taps and drags send exactly the placement or removal an independent pick predicts, or
nothing.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player taps an empty site and a slot is free, **Then** exactly one
   placement of a well with the panel's strength and sense on that site is sent.
2. **Given** a placed well, **When** the player drags it and lifts on another free site, **Then** exactly one placement
   moving that slot's well (same strength and sense) to the new site is sent; lifted outside the enclosure, exactly one
   removal is sent; lifted on its own site, an occupied site or elsewhere inside, nothing is sent.

### User Story 2 - Scrub through the swim (Priority: P1)

A player drags sideways along the swim scrubber below the dish to move the shown tick through the predicted swim; the
swimmers and ribbons follow and nothing else changes.

**Why this priority**: reading where the swarm goes over time is how the player plans the wells.

**Independent Test**: scripted scrubs show exactly the tick an independent computation predicts; no kernel action is
sent.

### User Story 3 - Freeze the field to compare (Priority: P2)

A player taps the dish field (away from wells and sites) to freeze it: while frozen, dragging a well previews only the
gauges and keeps the committed swim drawn, so the player can compare; tapping again unfreezes.

**Independent Test**: the freeze toggle changes only presentation; the previews in both states equal an independent
computation; the digest never changes.

### User Story 4 - Look around the dish and come back (Priority: P1)

A player orbits the dish with two fingers within bounds to see depth and returns to the authored view by a double tap
outside the dish or "Reset view"; the view never changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (slot, site, strength and sense, place,
remove, tick − and +, play, undo, redo, next level, "Freeze" and "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap is below 10 points and lifted within 0.5 s; a press lifted at 0.5 s or
  later without moving does nothing; two taps outside the dish within 0.35 s and 22 points reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A tap on an empty site with every slot used:** nothing is sent; the reason is given in words.
- **Targets under each other** (a well on its site, a site near the rim): the target drawn last is picked, as drawn.
- **A change the kernel refuses** (no action left, the stage): sent; the refusal is logged and shown with its reason
  code. A drop that changes nothing is never sent.
- **A finished play (won or failed):** gestures send no kernel action (the scrubber still shows ticks) and the
  description says the play is over (undo or next level); orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** a preview clears and nothing is sent.
- **Very small or very wide views:** picking, the scrubber and orbit work at every supported aspect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1904-001**: A tap on an empty site while playing, with a free slot, MUST send exactly one placement of a well
  with the panel's strength and sense in the first free slot; with no free slot it MUST send nothing and say why.
- **FR-R02G1904-002**: A drag that starts on a placed well while playing MUST preview the swim with the well moved to
  the site nearest the finger (or removed, outside the enclosure) and, on release on another free site, send exactly one
  placement moving that slot's well; on release outside the enclosure, exactly one removal; any other release MUST send
  nothing.
- **FR-R02G1904-003**: A drag along the swim scrubber MUST show the tick nearest the finger (presentation only) in any
  stage and MUST send no kernel action.
- **FR-R02G1904-004**: The well preview MUST be presentation only: the previewed swim (ribbons, lit cells and gauges, or
  only the gauges while frozen), never entering the digest, the snapshot's game state or the kernel.
- **FR-R02G1904-005**: A tap on the dish field away from wells and sites MUST toggle the freeze, presentation only.
- **FR-R02G1904-006**: Picking MUST be analytic and deterministic: each well's and site's projected disc and the
  scrubber's projected band through the drawn camera (orbit included), grown by a fixed margin, the one drawn last
  first; the dish field is the projected enclosure; anything else is empty space.
- **FR-R02G1904-007**: Two-finger orbit MUST stay within fixed yaw and pitch bounds, keep the scene inside the view with
  a 5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot's game state or the kernel; a double
  tap outside the dish or "Reset view" returns to the authored view.
- **FR-R02G1904-008**: Gestures on a finished play, cancelled touches and second fingers MUST send no kernel action.
- **FR-R02G1904-009**: The panel MUST keep every action available without gestures and gain "Freeze" and "Reset view";
  every certified witness MUST be replayable through panel actions within its budget.
- **FR-R02G1904-010**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code. Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: its state (idle, site press, well press, well drag, scrubber press, scrub drag, field press,
  empty press, orbiting, cancelled), the touched target, the start and last points, the press time and the last tap's
  time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Well preview**: the slot dragged, the site under the finger (or removal), and the previewed swim or the reason
  nothing would change.
- **Gesture action**: place, move, remove, showTick, preview, clearPreview, toggleFreeze, resetView, explain; the
  placements, removals and the tick map onto the declared adapter controls `well.place`, `well.remove` and `clock.show`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1904-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and ticks equal an independent computation.
- **SC-R02G1904-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1904-003**: Orbit, the freeze and the well preview never change the digest in every scripted case.
- **SC-R02G1904-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G1904-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1904-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1904-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G19-05; announcements, haptics, sound and full accessibility
  in R02-G19-06; persistence in R02-G19-07. The snapshot schema stays 1 here (orbit, the shown tick, the freeze and the
  preview are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 474 (and 464) so every round-two game feels the same.
- "Drag up to three magnetic wells" is read as tapping sites and dragging wells between sites (three slots); "scrub
  speed" as scrubbing the shown tick through the swim; "tap freeze field" as a tap on the dish field toggling the freeze;
  playing the swim stays the panel's Play (a deliberate commitment, never a gesture side effect).
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Drag up to three magnetic wells | FR-R02G1904-001, 002, 004 |
| Scrub speed | FR-R02G1904-003 |
| Tap freeze field | FR-R02G1904-005 |
| Gesture-to-world actions (analytic picking) | FR-R02G1904-006 |
| Camera behavior (orbit, reset) | FR-R02G1904-007 |
| Undo, accessible panel | FR-R02G1904-008, 009, 010 |

## Negative Requirements / Excluded scope

- No new kernel action, no saved orbit, tick, freeze or preview, no device run before ImplementationLock-100, no
  availability before X-R02-G19.
