# Feature Specification: Fluid Art Playground — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `024-fap-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A02-P06 · ID namespace FR-A02-6##, SC-A02-6##, T-A02-6##

**Input**: User description: archived manual `apps/02-fluid-art-playground.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- Reuse A01's release tooling unchanged: `check_privacy_manifest.py`, `check_app_release.py` with `release.json`,
  `bundle_licenses.py`, VisualCoreUI's `AcknowledgementsView` and `check_release_symbols.py`. Generic additions go
  to VisualCore (constitution II).
- Device rows stay `pending-campaign-ii` until the implementation lock (CLAUDE.md §1, §8).
- Signing, store name, screenshots, the privacy-policy URL and App Store Connect are `owner-action` rows with exact
  steps (CLAUDE.md §5).
- No measured performance claim without device evidence.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Privacy is declared truthfully (Priority: P1)

A reviewer, or a person reading the App Store privacy label, needs the app's privacy declarations to match what the
shipped binary actually does.

**Why this priority**: A wrong privacy manifest or usage string blocks review and misleads people.

**Independent Test**: Build the Release app. Scan it for required-reason APIs and compare the result with the
manifest. Read the usage strings and the UI path that triggers each.

**Acceptance Scenarios**:

1. **Given** the Release build, **When** its binary and frameworks are scanned, **Then** every required-reason
   category found is declared with a reason that matches the code, and no category is declared without being found.
2. **Given** the app, **When** its Info.plist is read, **Then** the only usage string is Photos add-only. Its text
   says why, and it is used only when the person chooses to save from the share sheet.
3. **Given** a session, **When** the app's container is listed after use, **Then** the app has stored no personal
   data. It stores no settings, and keeps at most one temporary capture until the playground closes.

---

### User Story 2 — The release package is complete and inspectable (Priority: P1)

The owner needs everything to submit: icon, version, credits, store text, build and archive steps, and a checklist
where every row has a status and evidence or steps.

**Why this priority**: The manual's gate is "release checklist and artifact inventory are complete".

**Independent Test**: Run the shared release-readiness check on the built app with the app's release config.

**Acceptance Scenarios**:

1. **Given** the Release build, **When** the release check runs, **Then** it passes every item:
   - bundle ID, version 1.0.0 (build 1) and the export-compliance key;
   - exactly the allowed usage strings;
   - a privacy manifest and a compiled 1024 app icon;
   - the required documents;
   - a checklist with no row lacking a status.
2. **Given** the app icon, **When** it is regenerated from the app's own renderer, **Then** it matches the committed
   icon (provenance: no third-party art).
3. **Given** the Acknowledgements screen, **When** it is opened from the home screen, **Then** it lists every
   shipped component's license (ANGLE, VisualCore and the app) and passes the accessibility audit.
4. **Given** the store listing, **When** each claim is read, **Then** it maps to a passing test. Claims without device
   evidence (performance, compatibility) are absent.

---

### User Story 3 — Local data and crash recovery (Priority: P2)

A person whose app was killed during a capture must not be left with stray files. Since nothing is persisted, there is
no data to migrate; this must be stated and checked rather than assumed.

**Why this priority**: The manual requires "local data migration" and "crash recovery". The honest answer for this
app is that there is nothing to migrate, plus a cleanup of temporary captures.

**Independent Test**: Leave a capture file in the temporary capture folder as a killed session would, launch the
app, and check that the folder is empty. List the app's UserDefaults keys and stored files.

**Acceptance Scenarios**:

1. **Given** captures left by a killed session, **When** the app launches, **Then** they are removed. Nothing outside
   the app's temporary capture folder is touched.
2. **Given** the app's defaults domain, **When** it is read after a session, **Then** it holds no keys written by the
   app.
3. **Given** a future version that persists settings, **When** it does, **Then** the documented schema (the
   configuration's version 1) is the migration starting point. That is recorded in the docs; this build stores none.

---

### User Story 4 — Tests and device readiness have attached results (Priority: P2)

The release review needs every automated test result attached, and every device test either attached or explicitly
pending the device campaign.

**Why this priority**: The manual's gate is "all required automated and device tests have attached results".

**Independent Test**: Read the checklist rows for tests and devices, and follow each evidence reference to a ledger
check.

**Acceptance Scenarios**:

1. **Given** the full app suites on iOS 27.2 and 26.5, **When** they run enumeration-guarded, **Then** all pass. The
   checklist cites the run names.
2. **Given** D1, D2 and D3, **When** the checklist is read, **Then** each has rows marked `pending-campaign-ii` with
   the planned automation (device-campaign.md). None is reported as tested.

---

### User Story 5 — No unsupported promise remains (Priority: P3)

A person must not be promised features the app does not have.

**Why this priority**: The manual's gate is "unsupported promised features are removed from UI and marketing copy".

**Independent Test**: Search the UI strings, home copy, store text and README section for promises, and compare each
with the implemented features.

**Acceptance Scenarios**:

1. **Given** the home screen and store text, **When** they are read, **Then** every feature named exists and is
   tested. There is no "coming soon", no performance figure, and no physical-accuracy claim.

### Edge Cases

- The temporary capture folder is missing, unreadable, or holds a non-capture file: launch cleanup ignores errors and
  removes only the app's own capture folder.
- The privacy scan finds a category in an embedded framework (ANGLE): it is declared with the reason found by a
  source check, as in A01.
- A required-reason category appears in a Debug build but not in Release: only the Release build is authoritative.
- Acknowledgements at the largest accessibility text size: no clipped text.
- A store claim that depends on a device (frame rate, thermal behavior): removed, or marked pending, never stated.
- The owner has not created `Configs/Signing.local.xcconfig`: the unsigned build and all checks still run. Signing is
  an `owner-action` row.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A02-601**: The app MUST ship a privacy manifest declaring no tracking, no tracking domains and no collected
  data, plus exactly the required-reason categories found by the shared scan of the Release build, each with a reason
  that matches the code.
- **FR-A02-602**: The app MUST declare only the Photos add-only usage string. Its text and UI path (Capture → Share or
  Save Image → Save Image) are documented, and a test asserts the declared set.
- **FR-A02-603**: The app MUST have a 1024×1024 opaque app icon rendered by its own renderer, with a provenance test
  that compares the committed icon with a fresh render. Version 1.0.0 (1) and the export-compliance key (no
  non-exempt encryption) are set.
- **FR-A02-604**: The app MUST bundle the shipped components' license texts at build time and show them on an
  Acknowledgements screen reachable from the home screen, using VisualCoreUI's `AcknowledgementsView`.
- **FR-A02-605**: Temporary captures MUST live in one app-owned temporary folder, and that folder MUST be emptied at
  launch (crash recovery). The folder handling is a reusable VisualCore component (constitution II).
- **FR-A02-606**: The app MUST persist nothing: no UserDefaults keys of its own and no files outside the temporary
  capture folder. A test asserts this, and the docs record configuration schema version 1 as the starting point for
  any future migration.
- **FR-A02-607**: `docs/apps/fluid-art-playground/` MUST contain `release.json`, `privacy-and-credits.md`,
  `store-listing.md` (claims → tests), `build-and-archive.md` (exact unsigned commands and owner-only steps) and
  `release-checklist.md`. Every checklist row is `verified` with ledger evidence, `pending-campaign-ii`, or
  `owner-action` with steps.
- **FR-A02-608**: The shared release check (`check_app_release.py`), the privacy scan, the Release symbol check and
  isolation MUST pass on the unsigned Release build, through `release_check.py`'s per-app release steps.
- **FR-A02-609**: The UI, home copy and store text MUST name only implemented, tested features, with no performance
  or device-compatibility claim.
- **FR-A02-610**: The full app suites, the accessibility audit (now including Acknowledgements), the contract check,
  the fast checks and the ProjectM regression (if VisualCore changes) MUST pass, and the checklist MUST cite them.

### Key Entities

- **Release config** (`release.json`): scheme, bundle ID, version, build, allowed usage strings, required docs,
  checklist, flags for privacy manifest, icon and licenses.
- **Checklist row**: area, item, status (`verified`, `pending-campaign-ii` or `owner-action`), evidence or steps.
- **Temporary capture folder** (VisualCore helper): a named folder under the app's temporary directory, holding
  uniquely named files, emptied at launch.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A02-601**: The privacy scan of the Release build reports 0 undeclared and 0 unused required-reason
  categories, and the usage-string test finds exactly one key.
- **SC-A02-602**: `check_app_release.py` passes every item for the app. The icon provenance test differs by a mean of
  at most 1/255.
- **SC-A02-603**: After a simulated killed session with 3 stale captures, launch cleanup leaves 0. Files outside the
  folder are untouched. The defaults domain has 0 app keys after a session.
- **SC-A02-604**: The full suites pass on iOS 27.2 and 26.5 (enumeration-guarded), including the Acknowledgements
  audit at default size and XXXL.
- **SC-A02-605**: Every store claim maps to a passing test. The checklist has 0 rows without a status, and D1–D3 rows
  are `pending-campaign-ii`.
- **SC-A02-606**: Release symbols 0, isolation PASS (one usage key), contract PASS, fast checks PASS, and the ProjectM
  regression 7/7 if VisualCore changed.

## Assumptions

- Store name, final bundle ID, screenshots, the privacy-policy URL, signing and App Store Connect are owner-only
  (CLAUDE.md §5). The placeholder bundle `dev.visualcore.FluidArtPlayground` is owner-approved for development.
- "Local data migration" is satisfied by persisting nothing and documenting the schema starting point; no migration
  code is written for data that does not exist.
- Device tests are planned in device-campaign.md and run after the implementation lock.
- ANGLE's embedded frameworks are the same as A01's, so their required-reason findings and reasons are reused after
  the scan confirms them.

## Traceability

| Source | Covered by |
|---|---|
| Manual Phase 06 deliverable: privacy and permission strings | FR-A02-601, FR-A02-602, SC-A02-601 |
| Manual Phase 06: accessibility | FR-A02-604, FR-A02-610, SC-A02-604 |
| Manual Phase 06: App Store asset and credit review | FR-A02-603, FR-A02-604, FR-A02-607 |
| Manual Phase 06: local data migration | FR-A02-606, SC-A02-603 |
| Manual Phase 06: CPU/GPU/device tests | FR-A02-610, US4 (device rows pending) |
| Manual Phase 06: crash recovery | FR-A02-605, SC-A02-603 |
| Manual Phase 06: build/archive instructions | FR-A02-607, FR-A02-608 |
| Gate: release checklist and artifact inventory complete | FR-A02-607, SC-A02-605 |
| Gate: tests have attached results | FR-A02-610, US4 |
| Gate: unsupported promises removed | FR-A02-609, US5 |
| Manual §13 content and App Store review checklist | FR-A02-602, FR-A02-607, FR-A02-609 |

## Negative Requirements

- No fabricated or simulator-derived performance or compatibility claims.
- No signing, no upload, no App Store Connect action, no store-name decision by the agent.
- No new permission, no networking, no tracking, no analytics.
- No migration code for data that does not exist; no persisted settings in this release.
- No second renderer or EGL context; no ProjectM or LGPL code linked.
