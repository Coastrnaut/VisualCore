# Feature Specification: Effects Composer — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `185-ec-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A25-P06 (legacy ledger) · ID namespace FR-A25-6##, SC-A25-6##, T-A25-6##

**Input**: User description: archived manual `apps/25-effects-composer.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation): "Complete release readiness for Effects Composer: privacy/permission strings,
accessibility, App Store asset/credit review, local data migration, CPU/GPU/device tests, crash recovery, and
build/archive instructions. No fabricated measured performance claims."

Canonical overrides:
- **ADR-0009:** A25 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable; the experience's release documents feed the app's release. Its quality, privacy, accessibility and
  regression gates stand. Visuals are code only; the app makes no network request.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (`docs/apps/effects-composer/device-campaign.md`, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy: no video or animated export, no layers
    or masks, no RAW or HDR editing, no AI, no cloud, account or upload, no measured speed.
- **Picking and sharing are real here:** the person picks a picture with the system photo picker (out of process, no
  read permission, A25-P04) and shares an export with the system share sheet (A25-P05); Save Image in the share sheet
  uses the app's add-only Photos usage string (registration permission `photo-library-add`). The source scan therefore
  allows the picker and the share sheet in the controls only, and the copy check allows the word "share".
- **Gap built here:** G-RELEASE of `docs/apps/effects-composer/visualcore-contract.json`; its iOS 26.x runner half is
  cited at X-A25.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/178-gbl-p06-release`.

## Clarifications

### Session 2026-11-19

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Permissions:** `Catalog/registrations.json` gives `a25.effects-composer` the permissions `["photo-library-add"]`;
  the app's `NSPhotoLibraryAddUsageDescription` reads "Saves exported artwork to your photo library when you choose
  Save Image." (`Apps/VisualCore/Generated/Info.plist`, checked by `BundleTests`). `PhotosPicker` (PhotosUI) runs out
  of process and needs no usage string; the share sheet needs none.
- **Copy steps:** `scripts/release_check.py` builds `experience-release-a25` and `copy-claims-a25` from
  `docs/apps/effects-composer/release.json`. Over the experience's nine Swift files, the shared denylist
  `Configs/copy-claims-denylist.json` finds only the word "share" (five lines of `ECControls.swift`), a feature the
  experience has, so `copyCheck.allow` is `["share"]`.
- **Stored data:** the session snapshot (`ComposerCore`, schema 1, digest domain `a25.effects-composer.v1`: the chain
  file's body `{"nodes": [...]}`); `preset-<n>.json` (kind `a25.preset`, version 1, at most 69,632 bytes, embedding the
  chain file `a25.effect-chain` version 1); `presets.json` (kind `a25.preset-library`, version 1), at most 24 looks;
  export files in the temporary folder `EffectsComposer`, removed before the next export and when the experience
  closes. A picked picture is held in memory only. The refusals are `damaged`, `newer-version`, `too-large` and the
  chain file's codes.
- **Catalog entry:** the registration's summary and capabilities still describe A25-P02 (a picture made in code only);
  they must name import and export truthfully, keep "shader" (CatalogSearchTests) and stay within 300 characters.
- **Drawing failure:** `ComposerPresenter.draw` throws to the session; there is no test seam yet.
- **Interface chunk:** no A25 chunk exists; the next free chunk name after `f3` is `g3`.

- Q: Which statuses does the release checklist use? → A: The checker's: `verified` with evidence;
  `pending-campaign-ii` for device rows naming EC-D1 … EC-D7 of `docs/apps/effects-composer/device-campaign.md`;
  `owner-action` with the steps of `docs/release/build-and-archive.md`.
- Q: Which words does the experience's own claims scan refuse? → A: Whole words, case-insensitively, in the store
  text, the catalog entry and the interface Swift (controls, presenter, renderer, export, import, library and the
  adapter): video, animated, animation, layers, layer, masks, mask, RAW, HDR, AI, "machine learning", neural,
  professional, pro-grade, lossless, unlimited, real-time, instant, fps, cloud, sync, account, upload, Photoshop,
  Lightroom, Instagram, filter-pack. The store text must contain the phrase "Nothing is sent". Every test named in the
  claims table must exist.
- Q: What does the source scan refuse? → A: The A24 list in `Packages/ExperiencesCreative/EffectsComposer`
  (`URLSession`, `import Network`, `CLLocation`, `import CoreLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`,
  `installTap`, `CMMotion`, `CNContact`, `PHPhotoLibrary`, `import Photos`, `ASIdentifierManager`,
  `AppTrackingTransparency`, `identifierForVendor`, `UIDevice.current.name`, `isIdleTimerDisabled`, any `brightness =`
  write, `UIPasteboard`); `PhotosUI`, `PhotosPicker` and `ShareLink` everywhere except
  `Experience/ECControls.swift`, where each must appear.
- Q: How are crash recovery and the sample files proved? → A: A test-only `failNextDraw` seam in the presenter makes
  the next draw throw once (`ComposerDrawError.injected`). A test saves two looks, sets the seam and draws, so the
  session fails with the injected message; every storage file is byte-identical and a new session over the same
  storage lists and opens both looks. Committed fixtures under `ExperienceTests/Fixtures/`: `snapshot-v1.json`,
  `snapshot-newer.json`, `snapshot-damaged.json`; `preset-current.json`, `preset-newer.json`, `preset-damaged.json`;
  `presets-current.json`, `presets-newer.json`, `presets-damaged.json`. Current samples open; the newer and damaged
  snapshots are refused; a newer or damaged look file is listed as unreadable with its code; a newer index makes the
  library read only; a damaged index still lists the looks from their files; every file stays byte-identical.
- Q: Which interface journey runs? → A: `ECReleaseUITests` in the new chunk `g3` (serial): a fresh start shows the
  status "Ready", no effect row, the buttons `export-png`, `export-jpeg`, `export-heic` and `test-picture`, no `share`,
  and no saved look, and reads the spoken labels "Export as PNG" and "Use the test picture"; it takes under 60 s.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device without the person's choice (Priority: P1) 🎯

A reviewer reads one page: what Effects Composer stores (the chain in the session snapshot, the named looks and their
index, and export files written only for the share sheet), where and how they are removed; that a picked picture is
read only after the person picks it and is never stored; that nothing is sent over the network and a picture leaves
the device only through an export the person shares; which permission the app may ask and when; and that every built-in
picture and effect is made in code.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; run the source scan.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored data and its removal, the picker, the export and the add-only Photos
   prompt, says nothing is sent automatically, and lists the licences.
2. **Given** the experience's sources, **Then** no network, location, tracking, sensor, microphone, camera, photo
   library, contact, pasteboard, idle-timer or brightness use appears, and the picker and the share sheet appear in the
   controls only.

---

### User Story 2 - Recover without losing the looks (Priority: P1)

A drawing failure ends the session with a message; the saved looks are unchanged; a new session lists and opens them.
Stored files of every kind open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** saved looks, **When** a draw fails, **Then** the session fails with a message, every stored file is byte
   for byte unchanged, and a new session lists and opens them.
2. **Given** committed samples of the session snapshot, a look file and the looks index (current, newer, damaged),
   **Then** current samples open and newer and damaged ones are refused without a crash, every file byte-identical
   afterwards.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text and the catalog entry claim only what a test proves; the release checklist lists every result as
verified, pending the device campaign, or an owner action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text, the catalog entry and the interface's words, **Then** no refused word appears and every
   claim names a test that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - A first session in the app (Priority: P2)

In the one app, a first session opens on the built-in test picture with an empty chain, ready to edit, with no saved
look and no export to share.

**Why this priority**: interface evidence at the release gate (first-session flow).

**Independent Test**: the A25 interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **Then** the status reads "Ready", the chain holds no effect, the export buttons are
   offered, no share link is shown, and no saved look is listed.

### Edge Cases

- **A sample of a schema not yet written:** refused as newer.
- **Copy that promises video, layers, RAW, AI, a cloud library or an account:** refused.
- **A damaged looks index:** looks are still listed from their files; the index is rebuilt by the next change, never
  by reading.
- **A look file above its size limit:** refused as too large, the file kept.
- **Export files left behind by a killed session:** removed before the next export.
- **A device-only check (memory, frame time, export time, heat, the Photos prompt):** pending the campaign, never
  claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A25-601**: A privacy-and-credits page MUST list the stored data (session snapshot, looks and their index, export
  files), its place (the experience's own storage; exports in a temporary folder), its removal (by the person in the
  looks list, before the next export or on close for exports, or when the app is deleted), that a picked picture is
  never stored, "nothing is sent automatically", the add-only Photos prompt and its usage string, and the licence
  inventory.
- **FR-A25-602**: A source scan MUST find no network, location, tracking, sensor, microphone, camera, photo-library,
  contact, pasteboard, idle-timer, brightness or private-identifier use in the experience, and the picker and the share
  sheet only in the controls.
- **FR-A25-603**: A drawing failure MUST fail the session with a message, leave every stored file unchanged, and a new
  session MUST list and open the saved looks.
- **FR-A25-604**: Committed samples of the snapshot, a look file and the looks index MUST open or be refused as
  specified, each byte-identical after reading.
- **FR-A25-605**: The store listing, the catalog entry (summary and capabilities) and the interface copy MUST claim only
  what tests prove and contain no refused word; the catalog summary MUST stay within 300 characters and keep the words
  the catalog search tests expect.
- **FR-A25-606**: A release checklist MUST give every row a status (`verified`, `pending-campaign-ii`,
  `owner-action`) with evidence, and the experience's release steps MUST pass in the release checks; the known
  limitations (the truncated-PNG decode, the share sheet's missing completion, the 2,048-pixel limit, the half-float
  posterize boundary) MUST be listed in `docs/release/known-limitations.md`.
- **FR-A25-607**: A first-session interface journey MUST pass on iOS 27.
- **FR-A25-608**: G-RELEASE MUST be closed with evidence; README and testing documents MUST be current.

### Key Entities

- **Release documents**: privacy-and-credits, licences, store listing, release checklist, device campaign, contract,
  `release.json`.
- **Sample files**: snapshot, look file and looks index, each current, newer and damaged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A25-601**: The source scan reports 0 refused uses; the picker and the share sheet appear in exactly one file.
- **SC-A25-602**: After an injected drawing failure, 100% of stored files are byte-identical and all saved looks open in
  a new session.
- **SC-A25-603**: 9 of 9 sample files behave as specified.
- **SC-A25-604**: The claims scan finds 0 refused words, and every proving test it names exists.
- **SC-A25-605**: Every checklist row has a status and evidence; the experience's release steps pass.
- **SC-A25-606**: The first-session journey passes in under 60 seconds.

## Assumptions

- The device rows stay pending until ImplementationLock-100; no measurement is claimed.
- The sample files are generated once through the real encoders and committed.

## Traceability

| Source | Requirement |
|---|---|
| Privacy/permission strings | FR-A25-601, 602 |
| Accessibility | FR-A25-607 (spoken labels in the journey); device audits in device-campaign.md EC-D7 |
| App Store asset/credit review | FR-A25-601, 605 |
| Local data migration | FR-A25-604 |
| CPU/GPU/device tests | FR-A25-606 (automated results; device rows pending) |
| Crash recovery | FR-A25-603 |
| Build/archive instructions | FR-A25-606 (owner-action rows citing `docs/release/build-and-archive.md`) |
| Release checklist and artifact inventory | FR-A25-606 |
| Unsupported promised features removed | FR-A25-605 |
| Contract G-RELEASE | FR-A25-608 |

## Negative Requirements

- No measured performance claim; no network; no advertising, tracking or account; no photo-library read; no storage of
  a picked picture; no second renderer; no device run before ImplementationLock-100; no owner action performed.
