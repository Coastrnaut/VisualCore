# Feature Specification: Digital Aquarium — Phase 03 Editing, feeding and save system

**Feature Branch**: `070-da-p03-feeding` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A09-P03 (legacy ledger) · ID namespace FR-A09-3##, SC-A09-3##, T-A09-3##

**Input**: User description: archived manual `apps/09-digital-aquarium.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — tap-to-feed and decoration placement gestures; regression fixture —
  background/resume does not fast-forward the fish simulation; graphics-context ownership stays solely in the
  VisualCore host.
- **Gap built here** (contract `docs/apps/digital-aquarium/visualcore-contract.json`): G-FEEDPLACE app-local — food
  pellets that sink and are eaten or removed at the floor, fish that seek the nearest pellet within range, decor placed,
  moved and removed inside the tank with a bounded count, gesture conflicts resolved through the shared gesture
  arbitration; every gesture action also has a native control.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Feeding the fish (Priority: P1) 🎯

A person taps the water and a few food pellets appear at that spot and slowly sink. Nearby fish turn toward the food
and eat it; uneaten food disappears when it reaches the gravel.

**Why this priority**: the manual's MVP for this phase ("tap-to-feed").

**Independent Test**: a feed at a point adds pellets there; over the following simulated seconds the pellets sink,
fish within range move toward the nearest one, eaten pellets vanish, and the rest are removed at the floor.

**Acceptance Scenarios**:

1. **Given** a swimming aquarium, **When** the person taps the water, **Then** pellets appear at the tapped point and
   sink at a steady pace.
2. **Given** pellets in the water, **When** fish are within seeking range, **Then** the distance from the closest fish
   to its nearest pellet shrinks over the next seconds, and a pellet a fish reaches is eaten.
3. **Given** a pellet nobody eats, **When** it reaches the gravel, **Then** it is removed.
4. **Given** the most pellets allowed are already in the water, **When** the person feeds again, **Then** the feed is
   refused and nothing changes.
5. **Given** VoiceOver or no touch, **When** the person uses the Feed control, **Then** pellets drop at the top centre.

---

### User Story 2 - Arranging decorations (Priority: P1)

A person long-presses empty water to place the chosen decoration there, long-presses an existing decoration and drags
it to move it, and removes a decoration with a control. Decorations never leave the tank, and there is a limit to how
many can be placed.

**Why this priority**: the manual's MVP ("decoration placement gestures").

**Independent Test**: placing, moving and removing change the decor list exactly as asked, inside the tank, never
beyond the limit; each has a native control.

**Acceptance Scenarios**:

1. **Given** a chosen decoration kind, **When** the person long-presses empty water, **Then** a piece of that kind
   appears at that point (kept inside the tank).
2. **Given** a decoration, **When** the person long-presses it and drags, **Then** it follows the finger and stays
   inside the tank; releasing leaves it there.
3. **Given** the decoration limit is reached, **When** the person places another, **Then** it is refused.
4. **Given** a selected decoration, **When** the person uses Remove, **Then** it disappears.
5. **Given** no touch, **When** the person uses the native controls (choose kind, Add, choose piece, Move left/right/
   up/down, Remove), **Then** the same changes happen.
6. **Given** a quick tap, **When** it lands on water or on a decoration, **Then** it feeds and never places or moves
   decor; a long-press never feeds.

---

### User Story 3 - Leaving and returning (Priority: P2)

When the person leaves the app or the aquarium and comes back, the fish and the food continue from where they were;
time spent away does not make the simulation jump ahead. The pellets, decorations and the chosen decoration kind are
saved with the aquarium.

**Why this priority**: the manual's Phase 03 regression fixture.

**Independent Test**: a suspension of any length followed by a resume leaves the step count and every fish and pellet
where they were; a save and restore keeps pellets, decor and the chosen kind; an older saved aquarium opens with no food.

**Acceptance Scenarios**:

1. **Given** pellets sinking, **When** the app goes to the background and returns, **Then** the step count, the fish
   and the pellets are exactly as before the suspension and continue from there.
2. **Given** an aquarium with pellets and edited decor, **When** it is saved and restored, **Then** they are identical.
3. **Given** an aquarium saved by Phase 02, **When** it is restored, **Then** it opens with no pellets and the first
   decoration kind chosen.

### Edge Cases

- **Feeding while paused:** pellets are added but nothing moves until the motion resumes.
- **A tap outside the water (on the gravel):** pellets start at the swim bounds' nearest point.
- **Moving onto another decoration:** allowed (decor may overlap); fish are unaffected by decor.
- **Removing the piece being dragged:** the drag ends; nothing else changes.
- **Two fingers:** the gesture arbitration lets only one gesture win; a second finger cancels a pending long-press.
- **Invalid action values** (index of a missing piece, kind out of range, non-finite position): refused with a reason.
- **Habitat change:** pellets are cleared and the new habitat's starter decor replaces the edited decor.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A09-301**: A feed MUST add pellets at a point in the water, at most a bounded total in the water; a feed at the
  limit MUST be refused.
- **FR-A09-302**: Pellets MUST sink at a steady pace and be removed when a fish eats them or when they reach the floor.
- **FR-A09-303**: Fish within a seeking range MUST steer toward their nearest pellet, with the steering still capped
  and the Phase 01–02 bounds and speed guarantees still holding.
- **FR-A09-310**: A person MUST be able to place a piece of the chosen decoration kind at a point, move a piece and
  remove a piece; positions stay inside the tank and the count never exceeds the limit (12).
- **FR-A09-311**: Canvas gestures MUST be: tap → feed; long-press on water → place; long-press on a piece then drag →
  move. They MUST be resolved by the shared gesture arbitration so only one wins.
- **FR-A09-312**: Every gesture action MUST also be reachable through a native, labelled control.
- **FR-A09-320**: The saved state MUST hold the pellets and the chosen decoration kind (new schema) and MUST restore a
  Phase 02 state with no pellets and the first kind.
- **FR-A09-321**: A suspension MUST never advance the simulation; the resume continues from the saved step (fixture).
- **FR-A09-322**: The scenario manifest MUST add fixtures for feeding, decor editing and no fast-forward with food.

### Key Entities

- **Food pellet**: position, age; sinks; removed when eaten or at the floor.
- **Decoration choice**: the kind used by the next placement.
- **Decor piece** (from Phase 02): kind, position, rotation, scale.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A09-301**: A feed adds its pellets at the requested point in 100 % of accepted feeds; the pellet count never
  exceeds the limit over any sequence of feeds.
- **SC-A09-302**: Within 10 simulated seconds of a feed beside a school, at least one pellet is eaten for at least 18 of
  20 seeds; every uneaten pellet is gone once it reaches the floor.
- **SC-A09-303**: Placement, move and removal give exactly the requested decor list (positions clamped into the tank)
  in 100 % of accepted actions; 0 actions exceed the limit or leave the tank.
- **SC-A09-304**: A tap never places or moves decor and a long-press never feeds, in all gesture tests.
- **SC-A09-305**: After a suspension the step count and state are identical to before it, in 100 % of runs; save and
  restore round trips are identical; a Phase 02 state restores.
- **SC-A09-306**: Every aquarium test finishes in under 10 seconds.

## Assumptions

- Bubbles, caustics, depth layers and particles come in A09-P04; ambient mode in A09-P05.
- Decor does not collide with fish (fish swim over it; the depth is a drawing order only).

## Out of Scope

- Fish hunger, growth or death; food types; undo; free rotation or scaling gestures (rotation and scale stay as placed
  from the catalog defaults).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 03 (tap to feed and decoration placement) | FR-A09-301–303, 310–312; stories 1–2 |
| Manual P03 deliverable (editing, feeding and save system) | FR-A09-310, 320 |
| Manual P03 regression fixture (background/resume does not fast-forward) | FR-A09-321, 322; story 3 |
| Contract gap G-FEEDPLACE (matrix M10) | FR-A09-301–312 |
| Cross-cutting accessibility (native alternative for every gesture) | FR-A09-312 |

## Negative Requirements

- No second renderer or context; no artwork; no network; no claims about animal care or nutrition; no time-based
  catch-up after a suspension.
