# Feature Specification: Living Wallpapers — Phase 05 Resolution, colour and heat device tests

**Feature Branch**: `142-lw-p05-device-tests` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A19-P05 (legacy ledger) · ID namespace FR-A19-5##, SC-A19-5##, T-A19-5##

**Input**: User description: archived manual `apps/19-living-wallpapers.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: export progress, cancellation, error recovery and a local history (built in A19-P04), now proven in the
    app's interface;
  - regression fixture: the experience never claims to set wallpapers itself, checked on every screen text the
    interface shows;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-DEVICE of `docs/apps/living-wallpapers/visualcore-contract.json`, as a device-campaign plan.
  Its rows are {device} and stay pending until the campaign after ImplementationLock-100. No number is claimed from a
  simulator.
- **Experience A19 inside the one app:** still a candidate; interface tests launch it with the candidates argument.
- Follow `specs/135-ac-p05-device-qa`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- The controls already carry the identifiers `export`, `export-progress`, `export-cancel`, `export-retry`,
  `export-message`, `export-notice`, `export-offered`, `share`, `help`, `result-help` and `clear-history`, under the
  prefix `experience.a19.living-wallpapers.` (`WallpaperControls.swift`).
- The presenter's export limit comes from the context's maximum texture size, which on the simulator is larger than
  every template, so no template is refused there.
- Other experiences read a launch argument for tests (`-uitestTemporaryBookmarks` in Fractal Explorer). The interface
  chunks are named in `scripts/release_check.py`; `z2` is the last, and serial chunks are listed in `SERIAL_CHUNKS`.
- Ambient Clock's `device-campaign.md` is the plan's format: rows, device, procedure, threshold and status "pending
  device campaign".
- The phase starts at `bdb9fb1a` (the specify commit).

- Q: Which interface tests run, and in which chunk? → A: A new serial chunk `a3`, with `LWExportUITests` and
  `LWClaimsUITests`, launched like `ACSupport` with the candidates argument:
  - `LWExportUITests`:
    - a fresh start exports the iPhone SE template;
    - progress reaches its end, the result line names "PNG", the size and "sRGB", the share control appears, and
      the history lists the export;
    - a second test sets the export limit and shows the notice, then exports at the offered size.
  - `LWClaimsUITests` collects every static text and button label of the experience and of its help sheet, and finds
    none of the refused phrases. The help says the person sets the wallpaper.
- Q: How does the interface test get a size that does not fit? → A: A launch argument `-lwExportLimit <n>`, read
  only under `DEBUG || VISUALCORE_AUTOMATION`. It caps the presenter's export limit at n. Shipping builds ignore it,
  and a unit test covers the parsing and the cap.
- Q: Which campaign rows does the plan hold? → A: Rows LW-D1 to LW-D8 in `docs/apps/living-wallpapers/device-campaign.md`:
  - LW-D1: the size limit recorded on each device;
  - LW-D2: the largest template (iPad Pro 13-inch landscape) exports, or falls back as its notice says;
  - LW-D3: the written file's size and colour profile, read back on the device and after Save Image in Photos;
  - LW-D4: the thermal state during ten largest exports, every 5 s;
  - LW-D5: the memory footprint during the largest export;
  - LW-D6: the add-only Photos prompt on the first Save Image;
  - LW-D7: the declined path, where Files still works;
  - LW-D8: the accessibility audits at the default and the largest text size.

  Each row has its device (D1, D2, D3), procedure, threshold and "pending device campaign". No number is claimed.
- Q: Is a VisualCore change needed? → A: No. The contract's G-DEVICE closes with the plan, and its rows wait for
  devices.
- Q: What does the regression fixture refuse? → A: The phrases of the platform and help scans ("live wallpaper",
  "set as wallpaper", "automatically", "sets your wallpaper", "installs", "animated wallpaper"), case-insensitive,
  over the collected interface texts. The source scans stay as they are.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The export journey works in the app (Priority: P1) 🎯

In the one app, a person opens Living Wallpapers, picks a device, exports, sees the progress finish, the result line,
the share control and the new history entry; a cancelled export leaves no share control.

**Why this priority**: the MVP proven at the interface.

**Independent Test**: the interface test chunk on the iOS 27 phone simulator.

**Acceptance Scenarios**:

1. **Given** a fresh start, **When** an export runs, **Then** the result line names the format, size and sRGB, the
   share control appears and the history lists the export.
2. **Given** a size the device cannot render, **Then** the notice appears and exporting at the offered size works.

---

### User Story 2 - No screen claims what the app cannot do (Priority: P1)

Every text the experience shows (controls, notices, result, help) is free of claims that the app sets, installs or
animates the wallpaper.

**Why this priority**: the manual's regression fixture.

**Independent Test**: collect every visible text of the experience and of its help in the interface test; scan it.

**Acceptance Scenarios**:

1. **Given** every screen of the experience and its help, **Then** none of the refused phrases appears, and the help
   says the person sets the wallpaper.

---

### User Story 3 - The device campaign knows what to measure (Priority: P2)

The owner's device campaign has rows for each device fact the simulator cannot give: the real size limit, the largest
template's export or fallback, the written file's size and profile on device, heat during the largest export, memory
during export, the share sheet's add-only prompt and its declined path, and the accessibility audits.

**Why this priority**: G-DEVICE; resolution, colour and heat are device facts.

**Independent Test**: read the plan; every row has a device class, a procedure, a threshold and "pending".

**Acceptance Scenarios**:

1. **Given** the plan, **Then** each row names what is recorded, how, the pass condition and that it waits for the
   campaign; no row claims a number.

### Edge Cases

- **The simulator's size limit differs from a device's:** the interface test asserts the behaviour (fit or notice),
  never a number.
- **A row that needs the owner** (a device in hand, a Photos prompt): recorded as an owner action in the campaign.
- **Large text sizes:** the interface test runs at the default size; the audits at the largest size are a campaign
  row.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A19-501**: Interface tests MUST cover the export journey (progress to done, result line, share control,
  history entry) and the fallback notice with export at the offered size, in the one app on the iOS 27 phone.
- **FR-A19-502**: An interface test MUST collect every visible text of the experience and its help and find none of
  the refused claims.
- **FR-A19-503**: A device-campaign plan MUST list rows for the size limit, the largest template, the file's size and
  profile, heat, memory, the share sheet's prompt and declined path, and the accessibility audits, each pending.
- **FR-A19-504**: No measured device number MUST be claimed anywhere before the campaign.
- **FR-A19-505**: The GPU context stays in the host; no GL, wallpaper or Photos library call in the experience.

### Key Entities

- **Campaign row**: id, what, device class, procedure, threshold, status.
- **Interface journey**: steps and the identifiers they read.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A19-501**: The interface chunk passes on the iOS 27 phone, each test under 60 seconds.
- **SC-A19-502**: 0 refused phrases in the collected texts.
- **SC-A19-503**: 100% of campaign rows have device class, procedure, threshold and "pending"; 0 numbers claimed.
- **SC-A19-504**: Unit tests stay under 10 seconds each.

## Assumptions

- The campaign runs after ImplementationLock-100 with the owner's devices (D1, D2, D3); D3 stays on iPadOS 26.5.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 deliverable: resolution, colour and heat device tests | FR-A19-503, 504 |
| MVP: progress, cancellation, recovery and history | FR-A19-501 |
| Regression fixture: never claims to set wallpapers | FR-A19-502, SC-A19-502 |
| Gate: context ownership in the host | FR-A19-505 |
| Contract G-DEVICE | FR-A19-503 |
| Manual risks 2 and 3 (memory at high resolution, heat) | FR-A19-503 |

## Negative Requirements

- No device install or run before ImplementationLock-100; no simulator number presented as a device result; no
  wallpaper call; no network.
