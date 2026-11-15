# Feature Specification: Digital Aquarium — Phase 05 Ambient device testing and release content

**Feature Branch**: `072-da-p05-ambient` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A09-P05 (legacy ledger) · ID namespace FR-A09-5##, SC-A09-5##, T-A09-5##

**Input**: User description: archived manual `apps/09-digital-aquarium.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — persistent habitat configurations and safe restore; regression fixture —
  a long-running scene keeps the fish count, the particle count and the graphics memory bounded; graphics-context
  ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/digital-aquarium/visualcore-contract.json`): G-AMBIENT app-local — ambient
  mode lowers particles and movement within stated bounds, Low Power Mode and Reduce Motion select it, the in-scene
  brightness dims after an idle interval and restores on touch, and the system screen brightness is never changed.
- **Quality levels** are declared here: the experience's declared tier count matches the levels the drawing uses and
  the registration.
- **Device measurements** are planned in a device-campaign document; device tasks are tagged {device} and run only
  after ImplementationLock-100.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saved aquariums (Priority: P1) 🎯

A person saves the aquarium they arranged under a name, finds it later in a list of saved aquariums, opens it again
exactly as it was, and deletes the ones they no longer want. A damaged saved aquarium never breaks the list.

**Why this priority**: the manual's MVP ("persistent habitat configurations and safe restore").

**Independent Test**: saving, listing, opening and deleting round-trip exactly; a damaged or foreign file is skipped and
reported; the number and size of saved aquariums are bounded.

**Acceptance Scenarios**:

1. **Given** an arranged aquarium, **When** the person saves it under a name, **Then** it appears in the list with that
   name.
2. **Given** a saved aquarium, **When** the person opens it, **Then** the habitat, fish, plants, decorations, food and
   lighting are exactly as saved.
3. **Given** a saved aquarium, **When** the person deletes it, **Then** it disappears from the list and the current
   aquarium is unchanged.
4. **Given** a damaged or unreadable saved file, **When** the list is shown, **Then** that entry is skipped, the others
   are listed, and the person is told one could not be read.
5. **Given** the maximum number of saved aquariums, **When** the person saves another, **Then** the save is refused with
   a reason.

---

### User Story 2 - Ambient mode (Priority: P1)

A person who leaves the aquarium running as a calm background turns on ambient mode: fewer bubbles and motes, slower
calmer fish, and after a while without touches the scene dims itself; a touch brings the brightness back. With Low Power
Mode or Reduce Motion on, ambient behaviour is chosen automatically. The device's own screen brightness is never
touched.

**Why this priority**: the gap G-AMBIENT; the manual's "ambient" deliverable.

**Independent Test**: ambient lowers particle counts and fish speed within the stated bounds; the scene dims after the
idle interval and restores on a touch; Low Power Mode and Reduce Motion select ambient drawing; the system brightness is
never set.

**Acceptance Scenarios**:

1. **Given** ambient mode on, **When** the aquarium runs, **Then** bubbles and motes are at most half their usual count
   and fish cruise at a lower speed.
2. **Given** ambient mode, **When** no touch arrives for the idle interval, **Then** the scene dims to the ambient
   brightness; **When** the person touches the canvas, **Then** full brightness returns.
3. **Given** Low Power Mode or Reduce Motion, **When** the aquarium draws, **Then** it draws as in ambient mode (fewer
   particles and dimming) without changing the saved aquarium.
4. **Given** any mode, **When** the aquarium runs, **Then** the device's screen brightness is never changed.

---

### User Story 3 - Steady over long runs (Priority: P1)

An aquarium left running for a long time keeps the same fish, never accumulates particles or food, and does not grow
its use of graphics memory, also after opening, closing and reopening several times.

**Why this priority**: the manual's Phase 05 regression fixture.

**Independent Test**: over a long simulated run the fish count is constant, pellets, bubbles and motes stay within their
limits, and the drawing resources return to the same count after reopening.

**Acceptance Scenarios**:

1. **Given** a running aquarium with repeated feeds, **When** a long run is simulated, **Then** the fish count never
   changes and pellets, bubbles and motes never exceed their limits.
2. **Given** an aquarium opened and closed several times, **When** the drawing resources are counted, **Then** the
   count is the same after each reopening.

---

### User Story 4 - Graceful quality levels (Priority: P2)

On a hot or busy device the aquarium lowers its drawing cost step by step — fewer particles, then a simpler light
pattern — without changing the aquarium itself.

**Why this priority**: the declared quality levels the host's governor uses.

**Independent Test**: each level draws no more than the level above it; the aquarium's state never depends on the level.

**Acceptance Scenarios**:

1. **Given** each quality level, **When** the aquarium draws, **Then** the particle counts and the light pattern follow
   the level's budget.
2. **Given** a level change, **When** the aquarium continues, **Then** its state and digest are unchanged.

### Edge Cases

- **Saving with an empty or very long name:** an empty name gets a default name; names are cut to a maximum length.
- **Two saves with the same name:** both are kept (names need not be unique); each has its own identity.
- **Opening a saved aquarium of an older format:** it is migrated like any restored state.
- **Ambient mode while paused:** dimming still follows touches; nothing moves.
- **A touch during dimming:** brightness restores immediately; the touch still feeds or edits as usual.
- **Low Power Mode turned off:** drawing returns to the chosen mode at once.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A09-501**: A person MUST be able to save the current aquarium under a name, list saved aquariums, open one and
  delete one; the number of saved aquariums is bounded and a save beyond it is refused with a reason.
- **FR-A09-502**: Opening a saved aquarium MUST restore it exactly; damaged, foreign or unreadable saved files MUST be
  skipped and reported without affecting the others or the current aquarium.
- **FR-A09-510**: Ambient mode MUST be a saved choice of the aquarium; it MUST lower bubbles and motes to at most half and
  the fish cruise speed to a stated fraction, keeping every earlier bound.
- **FR-A09-511**: In ambient mode (or with Low Power Mode or Reduce Motion) the scene MUST dim to a stated brightness
  after a stated idle interval without touches and MUST restore on the next touch; the system screen brightness MUST
  never be changed.
- **FR-A09-512**: Low Power Mode and Reduce Motion MUST select ambient drawing (fewer particles, dimming) without
  changing the saved state.
- **FR-A09-520**: The experience MUST declare its quality levels; each level MUST lower or keep particle counts and the
  light pattern's cost relative to the level above; the state MUST never depend on the level.
- **FR-A09-530**: A long run MUST keep the fish count constant and pellets, bubbles and motes within their limits;
  drawing resources MUST return to the same count after closing and reopening.
- **FR-A09-531**: The scenario manifest MUST add fixtures for ambient mode and a long run with feeds.
- **FR-A09-540**: A device-campaign document MUST plan the device measurements (frame time per level, thermal state over
  ten minutes, memory, ambient dimming, saved aquariums, VoiceOver, Dynamic Type, Reduce Motion), all pending until
  ImplementationLock-100.

### Key Entities

- **Saved aquarium**: a name, an identity, the saved aquarium state; stored in the experience's own storage.
- **Ambient mode**: a saved on/off choice; an effective ambient drawing state also selected by Low Power Mode and
  Reduce Motion.
- **Quality level**: a declared drawing budget (particles, light pattern).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A09-501**: 100 % of save/open round trips are identical; 100 % of damaged files are skipped and reported; saves
  beyond the limit are refused in 100 % of attempts.
- **SC-A09-502**: In ambient mode bubbles and motes are at most half their normal counts at every tested step and the
  fish cruise at the stated fraction of their normal speed.
- **SC-A09-503**: Dimming starts after exactly the idle interval without touches and ends on the first touch, in every
  test; the system brightness is never set (no such call exists in the experience).
- **SC-A09-504**: Over 10,000 steps with a feed every 100 steps, the fish count is constant and every limit holds; the
  drawing-resource count after the fifth reopening equals the count after the first.
- **SC-A09-505**: Each quality level draws no more particles than the level above it; the digest is identical at every
  level.
- **SC-A09-506**: Every aquarium test finishes in under 10 seconds.

## Assumptions

- Store listing, privacy and release documents come in A09-P06.
- Saved aquariums live only on the device (no sync, no export).

## Out of Scope

- Sharing or exporting saved aquariums; scheduled ambient mode; changing the device's brightness or lock behaviour.

## Traceability

| Source | Requirement |
|---|---|
| Manual P05 MVP (persistent habitat configurations and safe restore) | FR-A09-501, 502; story 1 |
| Manual P05 regression fixture (long-running scene bounded) | FR-A09-530, 531; story 3 |
| Contract gap G-AMBIENT (M15) | FR-A09-510–512; story 2 |
| Matrix M14 (persistence library), M16 (quality tiers) | FR-A09-501, 520; story 4 |
| Device campaign (Auto-Creator.md section 23) | FR-A09-540 |

## Negative Requirements

- No second renderer or context; no network; no change to the system screen brightness or idle timer; no measured
  performance claims before the device campaign.
