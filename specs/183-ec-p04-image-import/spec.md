# Feature Specification: Effects Composer — Phase 04 Image import

**Feature Branch**: `183-ec-p04-image-import` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A25-P04 (legacy ledger) · ID namespace FR-A25-4##, SC-A25-4##, T-A25-4##

**Input**: User description: archived manual `apps/25-effects-composer.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation; the manual titles the phase "Still export/presets", but its gates are image import).

Canonical overrides:
- **Phase gates (manual §9 Phase 04), binding:**
  - MVP: local image import via the system picker with scoped access;
  - regression fixture: an imported image's colour profile and orientation are handled correctly;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-IMPORT and the upstream U-RGBAUPLOAD of `docs/apps/effects-composer/visualcore-contract.json`.
  Presets were built in A25-P03; still export is A25-P05.
- **VisualCore change:** VisualCoreRendering gains one additive public upload of RGBA bytes into a render target, with
  `///` docs, tests, the API baseline update and the seven-step ProjectM reference regression in two chunks, after
  `specs/175-gbl-p03-runner-probe`.
- **Privacy:** the picker runs out of process; nothing is read without the person's pick; no permission is asked.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use my own picture (Priority: P1) 🎯

A person opens the system picker, chooses a photo, and the chain is applied to it in the preview; they can return to the
built-in test picture at any time.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: hand the import a picture's data as the picker would, and read the preview's source.

**Acceptance Scenarios**:

1. **Given** a picked picture, **When** imported, **Then** the preview's source is that picture and the chain is applied
   to it.
2. **Given** a cancelled pick, **When** the picker closes, **Then** the source stays as it was.
3. **Given** an imported picture, **When** "use the test picture" is chosen, **Then** the built-in picture returns.

---

### User Story 2 - The picture looks the right way up and the right colours (Priority: P1)

A photo taken sideways appears upright, and a photo with a wide-gamut colour profile shows the colours it shows in
Photos, converted to the preview's colour space.

**Why this priority**: the manual's regression fixture for this phase.

**Independent Test**: import generated pictures tagged with each orientation and with a wide-gamut profile; read chosen
pixels.

**Acceptance Scenarios**:

1. **Given** pictures tagged with each of the eight orientations, **When** imported, **Then** a marked corner appears at
   the top left every time.
2. **Given** a picture with a wide-gamut profile, **When** imported, **Then** a known colour matches its standard-gamut
   value within a stated tolerance.

---

### User Story 3 - Large and broken pictures are handled (Priority: P2)

A picture larger than the limit is scaled down so its longer edge equals the limit; a damaged file is refused with a
message; neither leaves the preview broken.

**Independent Test**: import an oversized and a damaged picture.

**Acceptance Scenarios**:

1. **Given** a picture larger than the limit, **When** imported, **Then** its longer edge equals the limit and its shape
   is kept.
2. **Given** damaged data, **When** imported, **Then** it is refused with a message and the source is unchanged.

---

### User Story 4 - The picture survives a context loss (Priority: P2)

After a graphics context rebuild, the imported picture is still the source.

**Independent Test**: import, rebuild the context, read the source.

**Acceptance Scenarios**:

1. **Given** an imported picture, **When** the context is rebuilt, **Then** the next frame's source equals the picture
   before the rebuild.

### Edge Cases

- **A picture smaller than 8 pixels on a side:** refused as too small.
- **A picture with transparency:** alpha kept.
- **A restored session:** the imported picture is not stored; the built-in picture is shown.
- **Data far larger than any picture should be:** refused before decoding.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A25-401**: VisualCoreRendering MUST offer a public upload of RGBA bytes into a render target, refusing a wrong
  length, an unsupported format and a stale target, documented and tested, with the API baseline and the reference
  regression updated.
- **FR-A25-402**: The experience MUST import a picture only through the system picker the person opens, decode it on the
  CPU into RGBA bytes in the preview's colour space with its orientation applied, and make it the preview's source.
- **FR-A25-403**: A picture larger than the limit MUST be scaled so its longer edge equals the limit; damaged, too small
  or too large data MUST be refused with a message and leave the source unchanged.
- **FR-A25-404**: The decoded bytes MUST be kept so the source is uploaded again after a context loss; the imported
  picture MUST NOT be stored.
- **FR-A25-405**: The person MUST be able to return to the built-in test picture.
- **FR-A25-406**: Every public name MUST carry documentation; G-IMPORT and U-RGBAUPLOAD MUST be closed with evidence.

### Key Entities

- **Imported picture**: RGBA bytes, width, height, the decoding's orientation and colour conversion applied.
- **Import result**: the picture or a refusal with a code and message.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A25-401**: 8 of 8 orientations put the marked corner at the top left.
- **SC-A25-402**: A wide-gamut colour matches its standard-gamut value within the stated tolerance.
- **SC-A25-403**: Oversized pictures keep their shape and their longer edge equals the limit; 100% of damaged, too small
  and too large inputs are refused.
- **SC-A25-404**: The source is byte-identical before and after a context rebuild.
- **SC-A25-405**: The reference regression passes 7 of 7 steps after the VisualCore change; each unit test finishes in
  under 10 seconds.

## Assumptions

- The test pictures are generated in code (no photograph is bundled).
- The picker itself cannot be driven by unit tests; its data is handed to the same import path.

## Traceability

| Source | Requirement |
|---|---|
| MVP: local image import via the system picker with scoped access | FR-A25-402, 405 |
| Regression fixture: colour profile and orientation handled correctly | FR-A25-402 |
| EGL/context ownership solely in the VisualCore host | FR-A25-401, 404 |
| Contract G-IMPORT, U-RGBAUPLOAD | FR-A25-401–406 |

## Negative Requirements

- No photo-library read permission; no access beyond the picked item; no bundled photograph; no storage of the imported
  picture; no network; no second renderer.
