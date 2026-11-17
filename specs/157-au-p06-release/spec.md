# Feature Specification: Aurora — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `157-au-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A21-P06 (legacy ledger) · ID namespace FR-A21-6##, SC-A21-6##, T-A21-6##

**Input**: User description: archived manual `apps/21-aurora.md` §9 Phase 06 `/speckit-specify` prompt (verbatim in
the invocation).

Canonical overrides:
- **ADR-0009:** A21 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable, and the experience's release documents feed the app's release. Its quality, privacy, accessibility
  and regression gates stand.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy (no aurora forecast, no weather, no
    required background sound, no always-on screen, no scientific depiction, no therapeutic or sleep claim).
- **Gap built here:** G-RELEASE of `docs/apps/aurora/visualcore-contract.json` (the A21 copy-claims and
  experience-release steps and the release documents); its iOS 26.x runner half is cited at X-A21.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/150-zg-p06-release`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Permissions:** `Catalog/registrations.json` gives `a21.aurora` the permissions `[]`, so no usage string is needed.
- **Copy steps:** `scripts/release_check.py` builds `experience-release-a21` and `copy-claims-a21` from
  `docs/apps/aurora/release.json`. The shared denylist refuses `audio`, `music`, `smooth`, `instant`, `share` and
  `camera`, measured numbers with units (`%`, `fps`, `hz`, hours) and the words `battery` and `frame rate`. Aurora
  shares nothing, so `copyCheck.allow` is empty.
- **Stored data:**
  - the session snapshot (schema 1, digest `a21.aurora.v1`);
  - `prefs.v1`, the experience value (kind `a21.preferences`, schema 1) with the refusals `damaged`,
    `newer-version` and `out-of-range`.

  A refused value opens the defaults with `readFailedMessage`, and it is overwritten only by the next accepted
  change. No temporary file is written.
- **Screen:** the experience never changes the idle timer or the brightness; the source shows no such call.
- **Drawing failure:** the presenter has no drawing-failure seam yet. `breakShaders` leads to the fallback sky, not to
  a failure.
- **Interface chunk:** the A21 interface chunk is `c3` (A21-P05).

- Q: Which statuses does the release checklist use? → A: The checker's:
  - `verified`, with evidence;
  - `pending-campaign-ii`, for device rows naming AU-D1 … AU-D8 of `docs/apps/aurora/device-campaign.md`;
  - `owner-action`, with the steps of `docs/release/build-and-archive.md`.
- Q: Which words does the experience's own claims scan refuse? → A: It scans the store text and the interface Swift
  (controls, presenter, the adapter's words and SkySound), matching whole words case-insensitively:
  - forecast, prediction, real-time aurora, live aurora, aurora activity, kp index, northern lights forecast,
    scientific, accurate, realistic, simulation of the aurora;
  - therapy, therapeutic, medical, clinical, wellbeing, well-being, mental health, stress relief, anxiety, heal,
    healing, sleep, insomnia, meditation, hypnotic;
  - always-on, keeps the screen on, screensaver, fps, unlimited.

  Every test named in the claims table must exist.
- Q: What does the source scan refuse? → A: The A20 list, in `Packages/ExperiencesCreative/Aurora`:
  - `URLSession`, `import Network`, `CLLocation` and `import CoreLocation`;
  - `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap` and `CMMotion`;
  - `CNContact`, `PHPhotoLibrary`, `import Photos` and `PhotosUI`;
  - `ASIdentifierManager`, `AppTrackingTransparency` and `isIdleTimerDisabled`;
  - any `brightness =` write.
- Q: How are crash recovery and the sample files proved? → A:
  - **Crash recovery:** a test-only `failNextDraw` seam in the presenter makes the next draw throw once
    (`SkyDrawError.injected`). A test saves the choices (a preset, the sound on), sets the seam and draws, so the
    session fails with the injected message. `prefs.v1` must be byte-identical, and a new session over the same
    storage opens with the saved preset and the sound on.
  - **Sample files:** committed fixtures under `ExperienceTests/Fixtures/`:
    - `snapshot-v1.json` (from the schema-1 example), `snapshot-newer.json` and `snapshot-damaged.json`;
    - `prefs-current.json`, `prefs-newer.json`, `prefs-damaged.json` and `prefs-out-of-range.json`.

    The current samples open. The newer and damaged snapshots are refused (`newerSchema`, `corrupt`). The refused
    preferences open the defaults with their code. Every file stays byte-identical after reading.
- Q: Which interface journey runs? → A: `AUReleaseUITests` joins chunk `c3`. A fresh start shows the canvas naming
  "Polar night", and `sound`, `still` and `reduced-flash` read off. The test takes under 60 s.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A reviewer reads one page: what Aurora stores (the open sky in the session snapshot and the saved choices), where and
how they are removed; that it sends nothing over the network; that it asks for no permission (no location, no
microphone); that it never keeps the screen awake or changes its brightness; and that every sky and the optional
sound are made in code.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; run the source scan.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored data and its removal, says nothing is sent and no permission is
   asked, and lists the licences.
2. **Given** the experience's sources, **Then** no network, location, tracking, sensor, microphone, camera, idle-timer
   or brightness API appears.

---

### User Story 2 - Recover without losing the choices (Priority: P1)

A drawing failure ends the session with a message; the saved choices are unchanged; a new session opens with them.
Stored values of every kind open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** saved choices, **When** a draw fails, **Then** the session fails with a message, the stored choices are
   byte for byte unchanged, and a new session opens with them.
2. **Given** committed samples of the snapshot and of the saved choices (current, newer, damaged), **Then** current
   samples open and newer and damaged ones are refused without a crash, every file byte-identical afterwards.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text claims only what a test proves and never claims a forecast, scientific accuracy, a therapeutic or
sleep benefit, an always-on screen or a measured speed or battery figure; the release checklist lists every result as
verified, pending the device campaign, or an owner action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text and the interface's words, **Then** no refused word appears and every claim names a test
   that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - A first session in the app (Priority: P2)

In the one app, a first session opens on the default sky with the sound off, the brightness limit at its default and
the still and reduced-flashing views off.

**Why this priority**: interface evidence at the release gate (manual §11 first-session flow).

**Independent Test**: the A21 interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **Then** the canvas names the default preset, the sound reads off, and the still and
   reduced-flashing views read off.

### Edge Cases

- **A sample of a schema not yet written:** refused as newer.
- **Copy that implies calm as a health effect or help with sleep:** refused; the copy describes what is shown.
- **Copy that names the optional sound:** it says "sound", never "audio" or "music" (shared denylist words).
- **A damaged stored choice:** the experience opens with the defaults and a message, and the stored value is not
  rewritten by reading.
- **A device-only check:** pending the campaign, never claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A21-601**: A privacy-and-credits page MUST list the stored data (snapshot, saved choices), its place and
  removal, "nothing is sent", "no permission is asked", that the screen is never kept awake nor its brightness
  changed, and the licence inventory.
- **FR-A21-602**: A source scan MUST find no network, location, tracking, sensor, microphone, camera, idle-timer or
  brightness API in the experience.
- **FR-A21-603**: A drawing failure MUST fail the session with a message, leave the stored choices unchanged, and a new
  session MUST open with them.
- **FR-A21-604**: Committed samples of the snapshot and of the saved choices MUST open or be refused as specified.
- **FR-A21-605**: The store text MUST make only claims a named test proves; refused words MUST not appear in the store
  text or the interface's words.
- **FR-A21-606**: The release checklist and release.json MUST list every document and result, and
  `docs/release/known-limitations.md` MUST gain an A21 section (no forecast, no weather, no background sound, device
  rows pending); the experience-release and copy-claims steps for A21 MUST pass. The device rows MUST be
  `pending-campaign-ii` and name their campaign rows AU-D1 … AU-D8 of `docs/apps/aurora/device-campaign.md`.
- **FR-A21-607**: The interface tests MUST cover the first-session defaults in the A21 chunk.

### Key Entities

- **Release checklist**: rows with status (verified, pending-campaign-ii, owner-action) and evidence.
- **Store text claims**: claim and proving test.
- **Sample files**: committed stored values with their expected outcome (opens, refused with a code).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A21-601**: 0 refused uses in the experience's sources.
- **SC-A21-602**: After a drawing failure, the stored choices are unchanged and the experience reopens with them.
- **SC-A21-603**: 0 refused words; every claim's test exists.
- **SC-A21-604**: The release checks and the interface chunk pass on iOS 27; unit tests under 10 s, interface tests
  under 60 s each.

## Assumptions

- The app's release, privacy manifest and build-and-archive documents are shared (`docs/release/`); this phase adds the
  A21 entries and section.
- Aurora declares no permission in `Catalog/registrations.json` and needs no usage string.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06: privacy/permission strings | FR-A21-601, 602 |
| Phase 06: crash recovery, local data migration | FR-A21-603, 604 |
| Phase 06: App Store asset/credit review; no fabricated performance claims | FR-A21-605, 606 |
| Phase 06: CPU/GPU/device tests, accessibility | FR-A21-606 (device rows), 607 |
| Phase 06: build/archive instructions | FR-A21-606 (owner-action rows) |
| Manual non-goals (forecast, weather, background audio, always-on) | FR-A21-605, 606 |
| Contract G-RELEASE | FR-A21-601–607 |

## Negative Requirements

- No device install before ImplementationLock-100; no signing, archive or upload; no store listing of its own.
- No network, permission, recording or downloaded asset; no measured figure claimed.
