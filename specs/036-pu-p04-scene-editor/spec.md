# Feature Specification: Particle Universe — Phase 04 Scene editor and persistence

**Feature Branch**: `036-pu-p04-scene-editor` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A04-P04 (legacy ledger) · ID namespace FR-A04-4##, SC-A04-4##, T-A04-4##

**Input**: User description: archived manual `apps/04-particle-universe.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009, Auto-Creator.md §17.3):** Particle Universe is an experience of the VisualCore app. All work is
  in its experience package and its app registration; the standalone Particle Universe target only keeps compiling
  until X-A04 retires it, and its sandbox screen and scene model are not extended.
- **Phase gates (manual §9 Phase 04):** MVP instanced or sprite batch rendering with a performance fallback; regression
  fixture: force singularities do not produce non-finite values; EGL and context ownership stays in the host.
- **Owner rulings of 2026-11-13:** tests are short; system accessibility audits wait for the device campaign;
  independent files go to parallel agents.
- **Out of scope:** import and export, sharing presets, built-in preset scenes (the manual's "starfield" journey and
  a preset gallery), editing the particle limit and time scale, more than one placed force (Phase 05+ or later ideas).
- **Device-only:** save and open timings and GPU behavior on devices. **Owner-only:** none.
- **What exists today (read-only audit of 2026-11-13, `Build/agent-notes/A04-P04-audit.md`, names re-verified):**
  - Editing: add, remove and select emitters; change family, size, lifetime, colour gradient; place, nudge, centre and
    strengthen one force; trails, trail strength and blend; pause, step, reseed. Missing: moving an emitter.
  - Persistence: only the automatic session snapshot (one current state). No named scenes, no library.
  - The scene format (version 1) validates on load (non-finite numbers, limits, counts), but stores neither the placed
    force nor the trail and blend settings, and has no migration path.
  - Each logged action carries at most 8 numbers, so a whole scene cannot be one action.
  - The Fractal Explorer experience already keeps a library of named saved items in the experience's own storage area.
  - Gates already met: batch rendering with a per-tier draw cap; finite forces at singularities (tested for placed
    forces); the experience draws only through the host's render context.

## Clarifications

### Session 2026-11-13

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`ExperienceStorage` (write, read, exists, list, remove; at most 64 files and 16 MiB, names up to 128 characters);
`ParticleScene` allows 1…8 emitters and 0…8 scene forces and throws `SceneError` on bad values; emitter positions
are scene coordinates (`SceneSimulation.placement(of:index:)` offsets them by 150 points).

- Q: What happens when a scene is saved under a name that already exists? → A: Saving always creates a new entry; a
  clashing name gets the next free suffix (" 2", " 3", …). Renaming to an existing name is refused with a message.
  Nothing is ever overwritten silently.
- Q: Which logged actions rebuild a scene when it is opened? → A: `scene.begin` (emitter count), then one
  `emitter.define` per emitter (family, x, y, size, lifetime, gradient index — 6 values), then `force.define` (kind,
  x, y, strength; kind 0 means none) and `look.define` (trails, trail strength, blend): at most 11 actions, each
  within the 8-value limit. The core validates the whole set and rejects the open if any value is invalid, leaving
  the scene unchanged.
- Q: How is an emitter moved in this slice? → A: With an `emitter.move` action carrying an absolute scene point,
  clamped to the scene bounds; the controls offer four direction buttons (fixed step) as the accessible way to
  move. Dragging on the canvas is deferred (it conflicts with force placement).
- Q: Where is the saved-scene format defined, and how is version 1 upgraded? → A: A `SceneDocument` (format version
  2: scene, placed force, trails, trail strength, blend) in the experience's pure core; version 1 is the existing
  `ParticleScene` document and upgrades through a migration step to version 2 with no force and default looks.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save a scene and open it again (Priority: P1) 🎯

A person builds a scene (emitters, a placed force, trails and blend), saves it under a name, keeps experimenting,
and later opens the saved scene to get exactly the same scene back, also after leaving the app.

**Why this priority**: saving is the MVP-05 deliverable of the phase; without it nothing made in the editor lasts.

**Independent Test**: build a scene, save it as "Nebula", change it, open "Nebula", compare the scene with the saved
one; relaunch and open again.

**Acceptance Scenarios**:

1. **Given** a scene with two emitters, a placed force and trails on, **When** the person saves it as "Nebula" and
   then opens it after changing the scene, **Then** the emitters, the force, the trail and blend settings equal the
   saved ones.
2. **Given** a saved scene, **When** the app is terminated and relaunched and the scene is opened, **Then** it is the
   same scene.
3. **Given** a scene opened from the library, **When** the session is replayed from its log, **Then** the replay
   reaches the same scene and the same state digest (opening is part of the replayable history).
4. **Given** the library, **When** the person renames or deletes a saved scene, **Then** the library shows the change
   and survives a relaunch.

---

### User Story 2 - Saved scenes are safe to open (Priority: P1)

Opening never crashes or produces a broken scene: damaged, truncated, non-finite or newer-version files are refused
with a message, and older files are upgraded.

**Why this priority**: a scene file is untrusted input that outlives app versions.

**Independent Test**: put damaged, truncated, NaN-containing, newer-version and old-version scene files in the
library and open each.

**Acceptance Scenarios**:

1. **Given** a damaged, truncated or non-finite scene file, **When** the library loads, **Then** the file is listed as
   unreadable (counted, never deleted) and opening it changes nothing.
2. **Given** a scene saved by a newer version, **When** it is opened, **Then** it is refused with "made by a newer
   version" and the current scene is unchanged.
3. **Given** a version-1 scene (no stored force, trails or blend), **When** it is opened, **Then** it opens with no
   placed force and the default trail and blend settings.

---

### User Story 3 - Move an emitter (Priority: P2)

A person moves the selected emitter with direction buttons to a new place in the scene, and the move
is saved with the scene.

**Why this priority**: the Phase 03 specification deferred moving emitters to this phase's editor.

**Independent Test**: select an emitter, move it, check its position, save and reopen.

**Acceptance Scenarios**:

1. **Given** a selected emitter, **When** a direction button is pressed, **Then** its position moves by the fixed step,
   clamped to the scene bounds, and particles start there.
2. **Given** a moved emitter, **When** the scene is saved and reopened, **Then** the position is kept.
3. **Given** VoiceOver, **When** the person uses the move control's button alternative, **Then** the emitter moves by
   a fixed step in the chosen direction.

---

### User Story 4 - Phase gates hold for opened scenes (Priority: P2)

Opened scenes render with the same batching and caps, and every force they contain stays finite at singularities.

**Why this priority**: the phase gates must hold for every scene a person can open, not only the defaults.

**Independent Test**: open a saved scene with forces at their extreme settings and run the simulation for a short
fixed number of steps; open a scene with the maximum emitters on each quality tier.

**Acceptance Scenarios**:

1. **Given** a saved scene with each force kind placed exactly on an emitter, **When** it runs 600 steps, **Then** every
   particle stays finite.
2. **Given** a saved scene with the maximum number of emitters, **When** it opens on each quality tier, **Then** the
   draw count stays within that tier's cap.

### Edge Cases

- **Name clashes:** saving under an existing name keeps both: the new entry gets the next free numbered suffix;
  renaming onto an existing name is refused.
- **Empty or long names:** empty names are refused; names longer than 64 characters are trimmed.
- **Storage full or write failure:** the save fails with a message; the previous file and the current scene stay.
- **Library limits:** at most the experience storage limits (file count and size); reaching them is reported.
- **Lifecycle interruption:** an interrupted save leaves either the old file or the new one, never a half file; the
  session snapshot still restores the current scene.
- **Memory pressure:** the library list is small text; scenes are loaded one at a time when opened.
- **Opening while paused:** the scene opens paused; play resumes it.
- **Reduce Motion and Reduce Flashing:** opened scenes respect the current settings, not the ones at saving time.

## Requirements *(mandatory)*

### Functional Requirements

**Save and open (story 1)**
- **FR-A04-401**: A person MUST be able to save the current scene under a name into the experience's own storage.
- **FR-A04-402**: A saved scene MUST hold the emitters (family, position, size, lifetime, gradient), the placed force
  (kind, position, strength), and the trail, trail-strength and blend settings.
- **FR-A04-403**: Opening a saved scene MUST reproduce exactly those values.
- **FR-A04-404**: Opening MUST be recorded in the session's action history as at most 11 small actions
  (`scene.begin`, `emitter.define` per emitter, `force.define`, `look.define`), so a replay of the history reaches the
  same scene and state digest; an invalid value rejects the whole open.
- **FR-A04-405**: The library MUST list saved scenes by name and allow open, rename and delete; it MUST survive a relaunch.

**Safe opening (story 2)**
- **FR-A04-410**: Saved scenes MUST carry a format version; a newer version MUST be refused with a message.
- **FR-A04-411**: Damaged, truncated or non-finite files MUST be refused, counted as unreadable, and never deleted.
- **FR-A04-412**: Version-1 scenes MUST open with no placed force and default trail and blend settings.
- **FR-A04-413**: A refused open MUST leave the current scene unchanged.
- **FR-A04-414**: A save MUST be atomic: a failure leaves the previous file and the current scene unchanged.

**Move an emitter (story 3)**
- **FR-A04-420**: The selected emitter MUST be movable to a scene point, clamped to the scene bounds, as one logged
  `emitter.move` action; dragging on the canvas is out of scope for this slice.
- **FR-A04-421**: The move MUST have a button alternative with a VoiceOver label and a 44-point target.

**Gates (story 4)**
- **FR-A04-430**: Every force kind in an opened scene MUST stay finite when placed on an emitter (fixture 4 extended).
- **FR-A04-431**: The per-tier draw cap MUST apply to opened scenes.
- **FR-A04-432**: The experience MUST keep drawing only through the host's render context.

**Common**
- **FR-A04-440**: The committed scenario digests MUST be regenerated only where state changes, and the scenario
  manifest MUST gain a "save and open" scenario.
- **FR-A04-441**: No network, no sharing, no third-party code; storage stays inside the experience's area.
- **FR-A04-442**: VisualCore needs no change; if one becomes necessary it is a separate approved task.

### Key Entities

- **Saved scene:** format version, name, the scene (emitters, limits), the placed force, trail, trail strength, blend.
- **Library entry:** identifier, name, last-saved time, file.
- **Open sequence:** the small logged actions that rebuild a scene from a saved scene.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A04-401**: A saved and reopened scene equals the saved values in 100% of fields, also after relaunch.
- **SC-A04-402**: Replaying a history that opened a scene reaches the same state digest in 3 of 3 runs.
- **SC-A04-403**: 4 of 4 bad files (damaged, truncated, non-finite, newer) are refused without changing the scene; a
  version-1 file opens.
- **SC-A04-404**: A moved emitter's position is kept after save and reopen in 100% of cases.
- **SC-A04-405**: 7 of 7 force kinds stay finite for 600 steps when placed on an emitter in an opened scene.
- **SC-A04-406**: Every new test finishes in under 10 seconds on the simulator.

## Assumptions

- The experience storage area and its limits (file count, total size, reserved session file) are the ones Fractal
  Explorer's bookmarks use.
- A scene with up to 8 emitters and one placed force opens in at most 20 logged actions.
- X-A04 (integration gate) follows this phase; the standalone app is retired there.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 deliverable (scene editor and persistence) | FR-A04-401–405, 420–421, US1, US3 |
| MVP-05 "save" | FR-A04-401–405, US1 |
| Manual §11 fixture 4 (singularities stay finite) | FR-A04-430, US4 |
| Phase gate: batch rendering with performance fallback | FR-A04-431, US4 |
| Phase gate: EGL ownership in the host | FR-A04-432 |
| Phase 01 plan: "Phase 04 adds the migration path" | FR-A04-410–412, US2 |
| Phase 03 spec: emitter moving deferred to Phase 04 | FR-A04-420–421, US3 |
| Negative requirements (no network, no sharing, no standalone work) | FR-A04-441, Input |
