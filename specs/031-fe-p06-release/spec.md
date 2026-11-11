# Feature Specification: Fractal Explorer — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `031-fe-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A03-P06 · ID namespace FR-A03-6##, SC-A03-6##, T-A03-6##

**Input**: User description: archived manual `apps/03-fractal-explorer.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates:**
  - The release checklist and the artifact inventory are complete.
  - All required automated tests have attached results. Device tests are recorded as pending the device campaign: no
    device run happens before the implementation lock.
  - Unsupported promised features are removed from the UI and the copy.
- **Reuse:** the A01/A02 release tooling (license bundling, privacy-manifest scan, release, isolation and
  Release-symbol checks), VisualCore's acknowledgements screen, temporary folders and named-document library.
- **Owner-only:** signing, App Store Connect, agreements and purchases stay with the owner (`BLOCKED_OWNER_ACTION`
  where a step needs them).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing about the person leaves the device or is stored without need (Priority: P1) 🎯

A person using the explorer must know exactly what the app keeps and asks for.

**Why this priority**: Constitution VIII and the release gate.

**Independent Test**: Inspect the built app's declarations and a session's stored data.

**Acceptance Scenarios**:

1. **Given** the built app, **Then** its only usage description is the Photos add-only text for saving a captured
   picture through the share sheet, its privacy manifest declares no tracking, no collected data, no tracking
   domains, and exactly the required-reason APIs found by the built-app scan, each with its reason.
2. **Given** a session (explore, save a bookmark, capture, take a tour, leave), **Then** the app's preferences hold no
   app keys, and the container holds only the bookmark the person saved and no capture files.
3. **Given** the app's networking surface, **Then** it makes no network connection (isolation check).

---

### User Story 2 - Store assets and credits are complete and honest (Priority: P1)

The owner can submit the app without inventing anything.

**Why this priority**: The release gate; owner-only submission stays separate.

**Independent Test**: Review the icon, version, acknowledgements and release documents.

**Acceptance Scenarios**:

1. **Given** the app, **Then** it has an icon made from its own render (no third-party art), version 1.0.0 (1), and an
   Acknowledgements screen reachable from the home screen listing every bundled third-party component with its full
   license text.
2. **Given** the release folder, **Then** it contains the release manifest, privacy and credits, store listing,
   build and archive instructions, and the release checklist, and the release check passes.

---

### User Story 3 - Saved data survives updates and crashes (Priority: P1)

A person's bookmarks keep working after an update, and a crash leaves no clutter.

**Why this priority**: The manual's "local data migration" and "crash recovery".

**Independent Test**: Load a committed version-1 bookmark fixture; simulate leftovers and a killed write.

**Acceptance Scenarios**:

1. **Given** a committed version-1 bookmark file (a golden fixture), **Then** this and every later build loads it with
   all fields intact; a bookmark file from a newer schema is reported and left untouched.
2. **Given** capture files left by a killed session, **Then** they are removed at the next launch, before any screen.
3. **Given** a bookmark write interrupted (a leftover temporary file next to the bookmarks), **Then** the library
   loads the intact bookmarks and leaves the leftover alone.

---

### User Story 4 - Verification is complete and claims are true (Priority: P1)

Every automated test passes on both simulator runtimes, the device rows are recorded as pending, and the home screen
and store copy promise only what exists.

**Why this priority**: The phase's last gate.

**Independent Test**: Run the full suites and the copy tests; read the checklist.

**Acceptance Scenarios**:

1. **Given** the app, **Then** its full unit and UI suites (including the accessibility audits at default size and
   XXXL) pass on iOS 27.2 and 26.5 under the enumeration guard, and the host and package suites pass.
2. **Given** the home screen and the store listing, **Then** every sentence names an implemented, tested feature; no
   performance number, device claim or unimplemented feature appears.
3. **Given** the release checklist, **Then** D1, D2 and D3 rows list the device runs (automation modes, container and
   defaults privacy, VoiceOver pass) as pending the device campaign, and owner steps as `BLOCKED_OWNER_ACTION`.

### Edge Cases

- A Release build scan that finds a required-reason API not declared: the manifest is updated with its documented
  reason, or the release check fails.
- Licenses missing from the bundle (a new dependency): the license check fails the build's release check.
- A newer-version bookmark file: reported, untouched (from feature 028).
- The Photos permission: never requested by the app itself; only the share sheet's "Save Image" uses it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A03-601**: The app MUST ship a privacy manifest derived from the Release build scan, and the privacy tests and
  scan MUST pass per US1.
- **FR-A03-602**: The app MUST have its own-render icon, version 1.0.0 (1), and an Acknowledgements screen from
  bundled license texts per US2.
- **FR-A03-603**: The app MUST keep version-1 bookmarks loadable (golden fixture) and recover from killed sessions per
  US3.
- **FR-A03-604**: The release documents (release manifest, privacy and credits, store listing, build and archive,
  release checklist) MUST exist and pass the release check; the device campaign plan is linked.
- **FR-A03-605**: The home screen and store copy MUST describe only implemented, tested features (copy tests).
- **FR-A03-606**: The full suites MUST pass on both runtimes, the Release build MUST have no automation symbols, the
  isolation check MUST pass, and the contract MUST record the gate.

### Negative requirements

- No measured performance claim anywhere; no device compatibility claim before the device campaign.
- No signing, upload, App Store Connect or purchase step performed by the agent.
- No network access; no analytics; no tracking.

### Key Entities

- **Release manifest**: scheme, bundle ID, version, build, allowed usage descriptions, required documents.
- **Bookmark fixture v1**: a committed file of schema 1.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A03-601**: The built-app scan and the manifest agree (0 undeclared required-reason APIs); 0 app preference keys
  and 0 capture files after a session.
- **SC-A03-602**: The release check passes with all 4 documents, the icon and the licenses.
- **SC-A03-603**: The v1 fixture loads with 100% of fields equal; leftovers are removed or ignored as specified.
- **SC-A03-604**: Full suites pass on both runtimes with the enumeration guard; Release has 0 automation symbols; the
  isolation check passes.
- **SC-A03-605**: Copy tests find no unimplemented or unmeasured claim.

## Assumptions

- The owner signs, archives and submits; build instructions describe the steps and mark them owner-only.
- The device campaign (after the implementation lock) supplies all device evidence named in the checklist.
- The bundle ID `dev.visualcore.FractalExplorer` is the approved placeholder identity.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06 — privacy/permission strings | FR-A03-601, US1 |
| Phase 06 — accessibility | FR-A03-606 (audits), US4 |
| Phase 06 — App Store asset/credit review | FR-A03-602, FR-A03-604, US2 |
| Phase 06 — local data migration, crash recovery | FR-A03-603, US3 |
| Phase 06 — CPU/GPU/device tests | FR-A03-606, US4 AC1/AC3 |
| Phase 06 — build/archive instructions; no fabricated performance claims | FR-A03-604, FR-A03-605 |
