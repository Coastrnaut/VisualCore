# Feature Specification: R02-G22-04 — Mycelium Architect: gameplay spatial interaction

**Feature Branch**: `514-mycelium-architect-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Draft

**Ledger gate**: R02-G22-04 (migration ledger, game feature of experience R02-G22) · ID namespace FR-R02G2204-###,
SC-R02G2204-###, T-R02G2204-###

**Input**: User description: the archived R02-G22-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Mycelium Architect (controls: "place nutrients
and blockers, advance growth pulses, undo edits"), with the canonical overrides of ADR-0009 and Auto-Creator.md
sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/514-mycelium-architect-gameplay-spatial-interaction`; FR-R02G2204-###,
  SC-R02G2204-###, T-R02G2204-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g22.mycelium-architect` (a registered candidate from
  R02-G22-03) inside the one app; the source's `Apps/MyceliumArchitect` and `Packages/GameModules/MyceliumArchitectCore`
  paths are superseded by `Packages/ExperiencesRound02/MyceliumArchitect` (Core, Experience and their tests).
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the prior-round device prerequisites
  (entitlement comes from the shared purchase controller, tier free). The source's "content count 84" is a milestone
  figure; the 100 certified levels of R02-G22-02 stand. **Device-only items:** touch feel and latency on D1/D2/D3,
  recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter, scene
  snapshot, geometry and camera of R02-G22-01 … 03.
- **Model:** feature 504 (Binary Gardens' gameplay spatial interaction: gesture controller, picker, view orbit and the
  presenter wiring), adapted to placements on sites, seeds dragged from the root, ghost growth, pulse scrubbing and cell
  inspection.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Place a nutrient or a blocker by touching a site (Priority: P1) 🎯

A player picks the nutrient or the blocker tool and taps an empty site: the item is placed and the predicted network
updates. Tapping a placed item clears it. Resting a finger on a site first shows the growth that placement would give as
a ghost, so the player can try before committing.

**Why this priority**: placing nutrients and blockers is the game's main move.

**Independent Test**: scripted taps on sites send exactly one placement or clear each, and a press-and-release shows the
ghost growth the kernel predicts for that placement.

**Acceptance Scenarios**:

1. **Given** the nutrient tool and an empty site, **When** the player taps it while playing, **Then** exactly one
   nutrient placement is sent for that cell.
2. **Given** a placed item, **When** the player taps it, **Then** exactly one clear is sent for that cell.
3. **Given** a finger resting on a site, **When** it is held, **Then** the ghost growth and verdict of that placement are
   shown and nothing is sent until release.

### User Story 2 - Seed a filament by dragging from the root (Priority: P1)

A drag that starts on the root and ends in one of the eight directions seeds that direction; dragging a seeded sprout
back into the root removes it.

**Independent Test**: scripted drags from the root send exactly one seed or unseed for the direction nearest the finger.

### User Story 3 - Advance and scrub the growth pulses (Priority: P1)

A drag along the weight gauge scrubs the shown pulse, so the player watches the veins grow and retreat; a tap on Run
commits the growth. Scrubbing never changes the game.

**Independent Test**: scripted scrubs set the shown pulse under the finger and never change the digest.

### User Story 4 - Inspect a cell or a terminal (Priority: P1)

A tap on a cell outside a placement tool's effect (a rock, a toxin, a terminal, a grown cell, the root) inspects it: its
words appear (nutrient value, occupant, when it is grown) and the cell is ringed; a second tap clears the inspection.

**Independent Test**: scripted taps inspect exactly the cell under the finger and change nothing in the game.

### User Story 5 - Look around and come back (Priority: P1)

Two fingers orbit the camera within fixed bounds; a double tap on empty space returns to the authored view.

**Independent Test**: at every orbit within bounds and every supported aspect the board stays inside the view.

### User Story 6 - Every move without gestures (Priority: P1)

Every action stays available in the panel, so every certified level can be won without touching the board.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap is below 10 points and lifted within 0.5 s; a press lifted at 0.5 s or
  later without moving commits the previewed placement only if a ghost was shown; two taps on empty space within 0.35 s
  and 22 points reset the view.
- **A tap on a cell that is not a site, or a full count:** nothing is sent; the kernel's reason is given in words.
- **A drag from the root that ends in an already seeded direction or with the seed limit reached:** nothing is sent; the
  reason is given; a drag back onto the root from a starting seed is refused as locked.
- **Cells under each other** (a terminal cap over its cell, a sprout over a neighbouring site): the target drawn last is
  picked, as drawn.
- **A finished play or a play not running:** placements and seeds send nothing (scrubbing and inspecting still work);
  the description says why; orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** a ghost clears and nothing is sent.
- **Opening, next level, reset and restore:** the ghost, the tool's cell and the inspection clear, the orbit returns to
  the authored view and the shown pulse to the pulses run.
- **Very small or very wide views, boards 8 … 16 cells wide:** picking, scrubbing and orbit work at every supported
  aspect; every projected value stays finite.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2204-001**: A tap on an empty site with the nutrient or blocker tool while playing MUST send exactly one
  placement of that kind for that cell; a tap on a placed item MUST send exactly one clear; any other tap on a site MUST
  send nothing and say why.
- **FR-R02G2204-002**: A press held on a site while playing MUST show the ghost growth and verdict of the placement the
  tool would make (or the clear), computed by the kernel's own rules, and send it only on release over the same cell.
- **FR-R02G2204-003**: A drag that starts on the root while playing MUST preview the seed in the direction nearest the
  finger and, on release beyond a fixed travel, send exactly one seed (or unseed, for a drag from a seeded sprout back
  onto the root); any other release MUST send nothing.
- **FR-R02G2204-004**: A press or drag on the weight gauge MUST show the pulse under the finger (presentation only) in
  any stage and send no kernel action.
- **FR-R02G2204-005**: A tap on any other cell MUST inspect it in any stage (ringed in the scene, the kernel's words for
  it in the description); a second tap or "Inspect: none" MUST clear the inspection.
- **FR-R02G2204-006**: Previews MUST be presentation only: the previewed report and verdict computed by the kernel's own
  rules (ghost veins as dashed tubes, a refusal named instead), never entering the digest, the snapshot's game state or
  the kernel.
- **FR-R02G2204-007**: Picking MUST be analytic and deterministic: each cell's projected square, the root's and each
  sprout's projected disc, the gauge's cast plate, through the drawn camera (orbit included), the one drawn last first;
  anything else is empty space.
- **FR-R02G2204-008**: Two-finger orbit MUST stay within fixed yaw and pitch bounds, keep the board and gauges inside the
  view with a margin of at least 5 % at every aspect 0.4 … 2.5 and never enter the digest or the kernel; a double tap on
  empty space or "Reset view" returns to the authored view.
- **FR-R02G2204-009**: Gestures outside playing, cancelled touches and second fingers MUST send no kernel action, and a
  gesture that does nothing for a stated reason MUST give that reason in words.
- **FR-R02G2204-010**: The gesture constants MUST be fixed public constants equal to feature 504's where shared, and only
  event timestamps MUST be read.
- **FR-R02G2204-011**: The panel MUST keep every action available without gestures (tool choice, cell placement, clear,
  seed and unseed by direction, run, undo, redo, pulse, inspect, reset view); every certified witness MUST be
  replayable through panel actions within its budget.
- **FR-R02G2204-012**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code. Undo and redo stay the kernel's exact undo and redo.
- **FR-R02G2204-013**: No preview, ghost or inspection MUST be carried by hue alone (ghost veins dashed, a refused ghost
  named in words, the inspected cell ringed), and the presenter MUST expose its gesture state, preview, inspected cell,
  tool and orbit for diagnostics, with no telemetry leaving the device.
- **FR-R02G2204-014**: The snapshot schema MUST stay 1: the orbit, the tool, the preview, the inspected cell and the shown
  pulse are not saved, and opening, next level, reset and restore return them to their defaults.

### Key Entities

- **Gesture controller**: its state (idle, site press, root press, seed drag, gauge press, scrub drag, cell press, empty
  press, orbiting, cancelled), the touched target, the start and last points, the press time and the last tap.
- **Tool**: nutrient or blocker (presentation state of the panel and gestures).
- **Orbit**: yaw and pitch offsets from the authored view.
- **Preview**: the change as a kernel action and the previewed report and verdict, or the kernel's refusal.
- **Inspection**: the inspected cell, if any (presentation only).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2204-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions, pulses and inspected cells equal an independent computation.
- **SC-R02G2204-002**: Second fingers, cancels and gestures outside playing send no kernel action in every scripted case.
- **SC-R02G2204-003**: Orbit, previews, inspection and scrubbing never change the digest in every scripted case.
- **SC-R02G2204-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the board stays inside the view with a
  margin of at least 5 %.
- **SC-R02G2204-005**: All 100 certified levels are won through panel actions alone, each within its budget.
- **SC-R02G2204-006**: For 200 scripted previews the previewed report and verdict (or refusal) equal the kernel's for the
  changed arrangement.
- **SC-R02G2204-007**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G2204-008** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G22-05; announcements, haptics, sound and full accessibility
  in R02-G22-06; persistence in R02-G22-07. The snapshot schema stays 1 here.
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 504 so every round-two game feels the same.
- "Place nutrients and blockers" is read as tapping sites with a chosen tool; "advance growth pulses" as the run and the
  pulse scrub; "undo edits" as the kernel's undo through the panel (a tap on a placed item also clears it).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Native gesture-to-world actions (place nutrients and blockers, seed, clear) | FR-R02G2204-001, 002, 003 |
| Advance growth pulses | FR-R02G2204-004 |
| Undo | FR-R02G2204-011, 012 |
| Camera behavior | FR-R02G2204-007, 008 |
| Renderer and state purity | FR-R02G2204-006, 014; SC-R02G2204-003 |
| Accessibility (panel parity, non-colour cues) | FR-R02G2204-011, 013 |
| Observability | FR-R02G2204-009, 013 |

## Negative Requirements / Excluded scope

- No new kernel action, no hints or progression, no sound or haptics, no persistence change, no device run before
  ImplementationLock-100, no availability before X-R02-G22.
