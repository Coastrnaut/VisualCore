# Feature Specification: VisualCore Music Lab — Phase 04 Presets and recovery UX

**Feature Branch**: `050-ml-p04-presets-recovery` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A06-P04 (legacy ledger) · ID namespace FR-A06-4##, SC-A06-4##, T-A06-4##

**Input**: User description: archived manual `apps/06-visualcore-music-lab.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — source/status indicator and audio-interruption recovery; regression
  fixture — the permission-denied path is still usable in demo mode; the graphics context stays solely with the audited
  VisualCore host.
- **Gap built here in VisualCore** (docs, public-API baseline, tests; reference regression at X-A06), from
  `docs/apps/visualcore-music-lab/visualcore-contract.json`: G-INTERRUPTION (interruption, route change and
  media-services reset recovery of the microphone source, with an injectable event source).
- **Presets** (v0.1 feature list "parameter presets, local persistence"; manual §6 `MusicPreset(sceneID, paletteID,
  mappings, schemaVersion)`): this phase saves and applies scene + mapping presets locally; colour palettes arrive in
  Phase 05 and join the preset format then (a new format version).
- **Experience:** `Packages/ExperiencesCreative/VisualCoreMusicLab`; no new permission; no new state field (applying a
  preset changes the scene and mappings through one action).
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`MicrophoneAudioSource` creates its `AVAudioEngine` and configures the shared `AVAudioSession` inside `start(into:)`
with no seam for tests, has `engineStartCount` as an internal test hook, and stops by removing the tap and deactivating
the session; `AudioSourceState` has `idle`, `running`, `failed(String)`; no experience code switches exhaustively over
it; `ExperienceStorage` writes atomically with a quota (used by `GeometryLibrary`, one file per item); the registry's
`make(id:storage:reduceMotion:reduceFlashing:)` already hands the experience its storage; actions carry ≤ 24 numbers.

- Q: How are system events and the engine made testable? → A: A public `AudioSessionEvent` enum (interruptionBegan,
  interruptionEnded(shouldResume:), routeLost, mediaServicesReset) with a pure `init?(notification name, userInfo)`; a
  public `AudioSessionEventMonitor` that observes an injectable `NotificationCenter` (default `.default`) for the
  session's interruption, route-change and media-services-reset notifications and calls a handler on the main actor;
  inside VisualCoreAudio an internal `MicrophoneCapture` protocol (start into a buffer → sample rate; stop) with the
  system implementation holding today's session and engine code, and an internal initialiser of `MicrophoneAudioSource`
  taking a capture factory for tests.
- Q: What changes in the source's public surface? → A: `AudioSourceState.interrupted` (new case); `MicrophoneAudioSource
  .handle(_ event:)` and `.resume()`; the source owns a monitor while running when created with the public initialiser.
  Route loss counts only for the reason "old device unavailable"; other route changes are ignored.
- Q: How is a preset applied as one action? → A: `preset.apply [scene 0…2, feature₀, gain₀, feature₁, gain₁, feature₂,
  gain₂]` (7 values); values for slots beyond the scene's parameter count must be 0 and are ignored; it sets the scene
  and that scene's choices; invalid values are refused like `mapping.set`.
- Q: What is the preset file format? → A: One file `preset-<uuid>.json` per user preset in the experience's storage:
  `{"choices": [{"feature": n, "gain": g}…], "format": 1, "id": "<uuid>", "name": "…", "saved": <seconds since 2001>,
  "scene": n}` with sorted keys; the `id` must match the file name; greater `format` → counted as newer, refused, never
  rewritten; any other undecodable file → counted as unreadable. Built-ins live in code with fixed names ("Spectrum",
  "Waveform rings", "Pulse geometry").
- Q: What does the status show and when is "Use demo signal" offered? → A: Status text "<source> — live" while running,
  "— paused by the system" while interrupted, "— stopped" when failed (with the reason as the message); the demo and
  file sources show "<source> — live". "Resume" appears while interrupted after an end without permission to resume;
  "Use demo signal" appears when the microphone failed (rebuild failure or start failure).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Always know what is playing and why it stopped (Priority: P1) 🎯

The person always sees which source is active and in which condition: live, paused by the system (a call, an alarm,
another app taking the audio), the input device gone (headphones unplugged), or stopped with an error — each with a
plain sentence and, where it helps, a button (Resume, Use demo signal).

**Why this priority**: the phase MVP ("source/status indicator").

**Independent Test**: drive the source through simulated system events; the status and message follow each event and
the offered button works.

**Acceptance Scenarios**:

1. **Given** the microphone running, **When** the system interrupts audio, **Then** capture stops, the status reads
   "Microphone — paused by the system" and no error is shown.
2. **Given** an interruption that ends with permission to resume, **When** it ends, **Then** capture restarts by itself
   and the status reads "Microphone — live".
3. **Given** an interruption that ends without permission to resume, **When** it ends, **Then** the status stays paused
   and a "Resume" button restarts capture.
4. **Given** the input device disappears or the audio services reset, **When** that happens, **Then** the source rebuilds
   itself and continues, or, if it cannot, says so and offers the demo signal.

---

### User Story 2 - Save and reuse looks (Priority: P1)

The person saves the current scene and its mappings as a named preset, applies a preset later in one tap, renames or
deletes their own presets, and starts from three built-in presets (one per scene).

**Why this priority**: the phase title ("presets") and journey 3 ("save a scene preset").

**Independent Test**: save, apply, rename and delete presets; the library survives a restart of the experience; a
damaged preset file is reported and ignored.

**Acceptance Scenarios**:

1. **Given** an edited Geometry scene, **When** it is saved as "Pulse", **Then** "Pulse" appears in the list; applying it
   after other changes restores the scene and its mappings exactly.
2. **Given** a saved preset, **When** it is renamed to a name already used, **Then** the name is made unique ("Pulse 2");
   deleting it removes it and its file.
3. **Given** an unreadable or newer-format preset file, **When** the library opens, **Then** it is counted and named in a
   plain message, never deleted or rewritten, and the other presets work.
4. **Given** the three built-in presets, **When** one is applied, **Then** its scene and mappings are shown; built-ins
   cannot be renamed or deleted.

---

### User Story 3 - Without the microphone, everything else still works (Priority: P1)

A person who denied microphone access (or whose access is restricted) uses Music Lab fully with the demo signal or a
file: all scenes, the mapping editor and presets work, and the microphone button explains how to allow access.

**Why this priority**: the phase regression fixture and the constitution's A06 rule (an alternative without the
permission).

**Independent Test**: with permission denied, choose the microphone (refused, explained), then use every scene, an
editor change and a preset; every action is accepted and every scene draws.

**Acceptance Scenarios**:

1. **Given** permission denied, **When** the microphone is chosen, **Then** it is refused with the Settings explanation and
   the demo keeps playing.
2. **Given** permission denied, **When** each scene is selected, a mapping is changed and a preset is applied, **Then**
   every action is accepted and every scene draws a non-blank picture of the demo signal.

### Edge Cases

- Interruption while the demo or a file plays: they are silent sources with no capture; they keep drawing (no pause).
- Interruption while the experience is in the background: capture is already stopped; on return the source restarts
  normally.
- Several events in quick succession (began, route lost, ended): the source ends in one consistent state; never two
  engines.
- Saving with an empty name: "Untitled"; long names cut to 60 characters.
- Storage full or write refused: the save is refused with a message; existing presets are untouched.
- Applying a preset made for more parameters than the scene has: refused (cannot happen with valid files; validated).

## Requirements *(mandatory)*

### Functional Requirements

**Recovery in VisualCore (story 1)**
- **FR-A06-401**: VisualCore MUST translate the system's audio-session notifications into source events: interruption
  began, interruption ended (with or without permission to resume), input route lost, media services reset; the event
  source MUST be injectable for tests.
- **FR-A06-402**: The microphone source MUST pause on interruption began (state "interrupted"), resume on ended with
  permission to resume, stay paused otherwise until asked to resume, and rebuild its engine on route loss and media-
  services reset; if a rebuild fails it MUST end in "failed" with a reason.
- **FR-A06-403**: At most one capture engine MUST be running at any time across any event sequence.

**Experience (stories 1–3)**
- **FR-A06-410**: The status MUST name the source and its condition (live, paused by the system, device lost, stopped
  with reason) and show a plain message with Resume or Use demo signal where applicable.
- **FR-A06-411**: Presets MUST hold a name, scene and that scene's mapping choices, be stored one file per preset in the
  experience's own storage (versioned; unreadable or newer files counted, never deleted or rewritten), and be saved,
  applied, renamed and deleted; names are cleaned and made unique.
- **FR-A06-412**: Three built-in presets (one per scene) MUST be available, read-only.
- **FR-A06-413**: Applying a preset MUST be one validated action that sets the scene and its mappings (state digest
  changes accordingly).
- **FR-A06-414**: With permission denied or restricted, every scene, the mapping editor and presets MUST remain usable
  with the demo or file source.
- **FR-A06-415**: Every new control (preset list, save, rename, delete, resume, use demo) has an accessible label and
  identifier.

**Common**
- **FR-A06-420**: No networking, accounts or analytics; no recording; presets contain no audio; no ProjectM/MilkDrop
  preset format.

### Key Entities

- **Source event**: interruption began, interruption ended (resume allowed or not), route lost, media reset.
- **Source condition**: live, interrupted, failed (reason), idle.
- **Music preset** (format 1): id, name, scene, mapping choices, saved time.
- **Preset library**: entries, unreadable count, newer count, last message.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A06-401**: Each of the four notification kinds (and their resume flag) maps to the right event in 100% of cases;
  unknown or malformed notifications map to no event.
- **SC-A06-402**: Across 50 seeded random event sequences, the microphone source (with an injected engine) never runs two
  engines, ends each sequence in a state consistent with the last event, and resumes only when allowed.
- **SC-A06-403**: Save → change → apply restores the scene and mappings exactly; rename makes names unique; delete removes
  the file; unreadable and newer files are counted and left byte-identical.
- **SC-A06-404**: With permission denied, every scene draws a non-blank picture and every editor and preset action is
  accepted (100% of the scripted steps).
- **SC-A06-405**: The nine scenarios and the fixture scenarios pass on iOS 27; the public-API baseline lists the new types,
  documented; every new test finishes in under 10 seconds.

## Assumptions

- System interruptions cannot be produced on the simulator on demand; the event mapping and the source's reaction are
  tested with injected notifications and an injected engine; real interruptions are part of the device campaign.
- The demo and file sources produce no sound, so they need no interruption handling (they keep drawing).
- Palettes join presets in Phase 05 (format 2 with migration).

## Out of Scope

- Sharing or exporting presets, cloud sync, preset thumbnails, colour palettes (Phase 05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 04 (source/status indicator and audio-interruption recovery) | FR-A06-401–403, 410 |
| v0.1 feature 05 (parameter presets, local persistence) | FR-A06-411–413 |
| Manual §9 Phase 04 fixture (permission denied still usable in demo mode) | FR-A06-414, SC-A06-404 |
| Manual §6 `MusicPreset(sceneID, paletteID, mappings, schemaVersion)` | FR-A06-411 (palette in Phase 05) |
| Journey 3 (save a scene preset) | User story 2 |
| Contract gap G-INTERRUPTION (M15) | FR-A06-401–403 |

## Negative Requirements

- No second capture engine, no capture while interrupted or in the background.
- No recording; presets never contain audio; no network.
- No ProjectM/MilkDrop preset format or names.
