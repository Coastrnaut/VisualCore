# Feature Specification: Digital Aquarium — Phase 04 Lighting, particles and accessibility

**Feature Branch**: `071-da-p04-waterfx` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A09-P04 (legacy ledger) · ID namespace FR-A09-4##, SC-A09-4##, T-A09-4##

**Input**: User description: archived manual `apps/09-digital-aquarium.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — bubbles, caustics, depth layers and environmental particles; regression
  fixture — the content catalog rejects missing or unsupported resources gracefully; graphics-context ownership stays
  solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/digital-aquarium/visualcore-contract.json`): G-WATERFX app-local (bubbles
  from vents ending at the surface, drifting motes, back/middle/front depth layers with tint, a caustics light pattern
  that holds still under Reduce Motion) and G-HABITATA11Y app-local (habitat description and rate-limited
  announcements through the shared announcement sink).
- **Quality tiers** are declared in A09-P05 (the levels that reduce particles and caustics arrive there).
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Living water (Priority: P1) 🎯

A person watching the aquarium sees streams of small bubbles rising from vents on the gravel, wobbling a little and
disappearing at the surface, and tiny motes drifting slowly through the water.

**Why this priority**: the manual's MVP ("bubbles … and environmental particles").

**Independent Test**: over a run, every bubble starts at a vent, rises, and ends at the surface; motes stay inside the
water; the number of each never exceeds its limit; nothing moves while the aquarium is paused.

**Acceptance Scenarios**:

1. **Given** a habitat, **When** it runs, **Then** bubbles rise from its vents and each disappears when it reaches the
   surface.
2. **Given** a running aquarium, **When** the count of bubbles and motes is checked at any moment, **Then** neither
   exceeds its limit.
3. **Given** the aquarium is paused or suspended, **When** time passes, **Then** bubbles and motes hold still.
4. **Given** Reduce Motion, **When** the aquarium runs, **Then** bubbles rise more slowly without wobble and motes
   barely move.

---

### User Story 2 - Depth and light (Priority: P1)

The aquarium looks deep: far plants and fish are smaller, paler and bluer than near ones, and a soft rippling pattern
of light plays over the gravel and the water, brighter at bright lighting.

**Why this priority**: the manual's MVP ("caustics, depth layers").

**Independent Test**: each fish and plant belongs to one of three depth layers; farther layers are drawn first, smaller
and tinted toward the water colour; the light pattern changes over time, repeats seamlessly across the tank, and holds
still with Reduce Motion.

**Acceptance Scenarios**:

1. **Given** fish in different layers, **When** the frame is drawn, **Then** back-layer fish are drawn behind and
   smaller than front-layer fish and their colour is closer to the water colour.
2. **Given** a running aquarium, **When** two moments are compared, **Then** the light pattern differs; with Reduce
   Motion it does not.
3. **Given** dim lighting, **When** the pattern is drawn, **Then** it is fainter than at bright lighting.
4. **Given** the light pattern cannot be prepared on this device, **When** the aquarium opens, **Then** it shows
   without the pattern and everything else works.

---

### User Story 3 - The aquarium in words (Priority: P2)

A person using VoiceOver hears what is in the aquarium — the habitat, each species with its count, plants, decorations,
food and whether the fish are swimming — and hears short announcements when something changes (food dropped, the
habitat changed, a decoration added or removed), never more than one every few seconds.

**Why this priority**: the gap G-HABITATA11Y; the aquarium must be perceivable without sight.

**Independent Test**: the description names every element for each state; changes produce one announcement each, at
most one per interval, and only with VoiceOver on.

**Acceptance Scenarios**:

1. **Given** each state (empty decor, food in the water, paused, each habitat), **When** the description is read,
   **Then** it names the habitat, each species with its count, plants, decorations, food and motion.
2. **Given** VoiceOver on, **When** the person feeds, **Then** one announcement says food was dropped.
3. **Given** several changes within the interval, **When** they happen, **Then** at most one announcement is made.
4. **Given** VoiceOver off, **When** changes happen, **Then** nothing is announced.

---

### User Story 4 - Damaged or unknown content (Priority: P2)

When the aquarium's content refers to something the app does not have — an unknown species, plant or decoration, or an
unsupported shape — the aquarium never crashes: a broken catalog is refused with a reason, a saved aquarium naming
unknown content opens the starter habitat instead, and drawing skips anything unknown.

**Why this priority**: the manual's Phase 04 regression fixture.

**Independent Test**: malformed catalogs are refused with a named reason; a saved state with unknown content is
refused and the starter habitat opens; a document with unknown kinds draws without them.

**Acceptance Scenarios**:

1. **Given** a catalog with a missing or unsupported item, **When** it is read, **Then** it is refused with a named
   reason and nothing else is affected.
2. **Given** a saved aquarium naming an unknown species or decoration, **When** it is restored, **Then** it is refused
   and the starter habitat opens.
3. **Given** a document with an unknown plant or decoration kind, **When** it is drawn, **Then** the unknown items are
   skipped and the rest is drawn.

### Edge Cases

- **A habitat with no vents:** no bubbles; motes still drift.
- **Lighting changes:** the light pattern's strength follows the lighting level immediately.
- **Feeding:** pellets are drawn in the middle layer; bubbles never interact with food or fish.
- **Many changes at once** (habitat change plus feed): one announcement, naming the most recent change.
- **Very small canvas:** bubbles and motes keep at least one pixel of size.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A09-401**: Each habitat MUST have bubble vents on the gravel; bubbles MUST rise from a vent with a small wobble
  and end at the surface; at most a bounded number of bubbles exist at once.
- **FR-A09-402**: Motes MUST drift slowly inside the water, a bounded number, wrapping at the tank edges.
- **FR-A09-403**: Bubbles and motes MUST be determined by the aquarium's own time (they hold while paused or suspended)
  and MUST NOT change the saved state.
- **FR-A09-404**: Reduce Motion MUST slow the bubbles, remove their wobble and nearly stop the motes.
- **FR-A09-410**: Every fish and plant MUST belong to one of three depth layers; farther layers MUST be drawn first,
  smaller and tinted toward the water colour.
- **FR-A09-411**: A caustics light pattern MUST be drawn over the gravel and the water, animated, seamless across the
  tank, scaled by the lighting level, still under Reduce Motion, and omitted without harm when it cannot be prepared.
- **FR-A09-420**: The canvas description MUST name the habitat, each species with its count, plants, decorations, food
  and motion state.
- **FR-A09-421**: Changes (food dropped, habitat changed, decoration added or removed, motion paused or resumed) MUST be
  announced through the shared announcement sink, only with VoiceOver on, at most one per interval.
- **FR-A09-430**: Content naming unknown or unsupported items MUST be refused with a named reason at catalog read and at
  restore, and skipped when drawn; nothing crashes.
- **FR-A09-431**: The scenario manifest MUST add fixtures for bubbles and motes over a run, and for a restore of unknown
  content.

### Key Entities

- **Bubble vent**: a point on the gravel of a habitat.
- **Bubble, mote**: drawn particles derived from the aquarium's time; never saved.
- **Depth layer**: back, middle or front; a scale and a tint amount.
- **Announcement**: a short sentence for one change, rate-limited.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A09-401**: Over 3,600 steps (60 s) of every habitat, every bubble starts at a vent and ends at the surface, and
  the bubble and mote counts never exceed their limits.
- **SC-A09-402**: The saved state and its digest are identical with and without bubbles, motes, caustics and Reduce
  Motion in 100 % of runs.
- **SC-A09-403**: Back-layer elements are drawn before and at most 75 % of the size of front-layer elements, and their
  colour is closer to the water colour, in every frame tested.
- **SC-A09-404**: Two frames 1 second apart differ in the light pattern; with Reduce Motion they are identical.
- **SC-A09-405**: The description names all elements in 100 % of the tested states; at most one announcement per
  interval and none with VoiceOver off.
- **SC-A09-406**: 100 % of malformed catalogs and unknown-content saves are refused with a reason; drawing a document
  with unknown kinds completes.
- **SC-A09-407**: Every aquarium test finishes in under 10 seconds.

## Assumptions

- Quality levels (fewer particles, simpler caustics) come in A09-P05 with ambient mode; this phase uses one level.
- The light pattern is drawn by a shader of the existing renderer path; no new renderer or context.

## Out of Scope

- Ambient mode and dimming (A09-P05); sound; fish reacting to bubbles; per-layer parallax from device motion.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 04 (bubbles, caustics, depth layers, environmental particles) | FR-A09-401–411; stories 1–2 |
| Manual P04 regression fixture (catalog rejects missing/unsupported resources gracefully) | FR-A09-430, 431; story 4 |
| Contract gap G-WATERFX (M11, M12, M13) | FR-A09-401–411 |
| Contract gap G-HABITATA11Y (M18) | FR-A09-420, 421; story 3 |
| Cross-cutting accessibility and Reduce Motion | FR-A09-404, 411, 420, 421 |

## Negative Requirements

- No second renderer or context; no artwork or textures from outside the code; no network; no flashing (the light
  pattern changes slowly); no announcements without VoiceOver.
