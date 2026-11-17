# Feature Specification: Interactive Anatomy — Phase 05 Scientific review and device QA

**Feature Branch**: `128-ia-p05-review-device-qa` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A17-P05 (legacy ledger) · ID namespace FR-A17-5##, SC-A17-5##, T-A17-5##

**Input**: User description: archived manual `apps/17-interactive-anatomy.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: reviewed factual text with citations and content provenance;
  - regression fixture: the VoiceOver structure list works without relying on 3D touch picking;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-REVIEW of `docs/apps/interactive-anatomy/visualcore-contract.json`, the review record. The
  editorial review checks each text against its cited sources and is done and recorded by the engineer. The clinical
  review is an owner action (BLOCKED_OWNER_ACTION). Until it is recorded, every text carries the
  not-reviewed-by-a-clinician label.
- **Device QA:** frame pacing, thermals, memory and the VoiceOver and accessibility audits on real devices are planned
  in a device-campaign document as {device} tasks. They run only after ImplementationLock-100.
- Follow `specs/107-sse-p05-review`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Know how far to trust the text (Priority: P1) 🎯

A learner or a teacher reads, for each structure, that its text was checked against its cited sources, by whom and
when, and that no clinician has reviewed it yet. The model is always labelled schematic and educational.

**Why this priority**: the phase's MVP and manual risk 1 (medical mistakes).

**Independent Test**: load the content and its review record; read every part's review lines and the labels.

**Acceptance Scenarios**:

1. **Given** the bundled content, **Then** every part's text has an editorial review entry (reviewer role, date,
   method, the sources checked).
2. **Given** no clinical review entry, **Then** every part shows "Not reviewed by a clinician." and the model shows
   "Schematic model for learning; shapes are simplified."
3. **Given** a review record that names an unknown part, lacks a date or reviewer, or claims a clinical review without
   a reviewer, **Then** it is refused with a typed reason.

---

### User Story 2 - Use it with VoiceOver alone (Priority: P1)

A blind learner never touches the 3D canvas. From the list alone they find every part, select it, hear it announced
and read its panel.

**Why this priority**: the phase's regression fixture.

**Independent Test**: drive the experience only through the list's actions and the panel's text, with no pointer
event; compare with a touch selection.

**Acceptance Scenarios**:

1. **Given** only list actions, **Then** every visible part can be selected, its selection is announced, and the panel
   shows its text, citations and review lines.
2. **Given** the same part chosen by a tap, **Then** the resulting state equals the list selection.

---

### User Story 3 - Plan the device checks (Priority: P2)

The owner gets one document listing every check to run on real devices, with pass criteria, to run after
ImplementationLock-100.

**Why this priority**: the phase's device QA.

**Independent Test**: read the device-campaign document; every task is tagged {device} and has a criterion.

**Acceptance Scenarios**:

1. **Given** the device-campaign document, **Then** it lists frame pacing, thermals, memory, VoiceOver, Dynamic Type,
   Reduce Motion and the accessibility audit, each with a pass criterion and the device class.

### Edge Cases

- **A clinical review entry that is recorded later:** the parts it covers show "Reviewed by <reviewer> on <date>." and
  the rest keep the not-reviewed label.
- **A review record of another content version:** refused, so a review never covers text it did not see.
- **The generated review document out of date:** a test fails.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A17-501**: The content MUST carry a versioned review record: one editorial entry per part (reviewer role,
  date, method, sources checked) and clinical entries only when the owner records one.
- **FR-A17-502**: Validation MUST refuse a review record with an unknown part, a missing reviewer or date, a content
  version other than the pack's, or a clinical entry without a named reviewer.
- **FR-A17-503**: Without a clinical entry for a part, its panel MUST say "Not reviewed by a clinician." The model
  MUST always be labelled "Schematic model for learning; shapes are simplified."
- **FR-A17-504**: The panel MUST show the part's review lines (editorial and, when present, clinical).
- **FR-A17-505**: Every part MUST be selectable from the list without any pointer event, with the same state, panel
  and announcement as a tap selection.
- **FR-A17-506**: A review document MUST be generated from the content and the record. A test MUST fail when the
  committed document differs.
- **FR-A17-507**: A device-campaign document MUST list the {device} checks with their pass criteria.

### Key Entities

- **Review record**: content version, entries (part, kind editorial or clinical, reviewer, date, method, sources).
- **Model statement**: the schematic-model sentence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A17-501**: 100 % of the 14 parts have an editorial entry and show the not-reviewed label.
- **SC-A17-502**: Each kind of invalid record is refused in a test that names it.
- **SC-A17-503**: All 14 parts are selected through list actions alone with the panel, announcement and state of a
  tap selection.
- **SC-A17-504**: The generated review document matches the committed one. Every test runs in under 10 s.

## Assumptions

- The editorial review is the engineer's own reading of every description against Gray's Anatomy (1918) sections and
  Terminologia Anatomica names; it is recorded truthfully as editorial, never as clinical.
- The interface test of the list through the app (UI test) comes with A17-P06's interface chunk.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 deliverable: scientific review and device QA | FR-A17-501–504, 507 |
| MVP: reviewed factual text with citations and provenance | FR-A17-501, 503, 504, 506 |
| Regression fixture: the VoiceOver list works without touch picking | FR-A17-505, SC-A17-503 |
| Context ownership in the host | no change to the renderer |
| Contract G-REVIEW | FR-A17-501–506 |
| Manual risk 1 (medical mistakes) | FR-A17-503 |

## Negative Requirements

- No claim of clinical review, accuracy or certification; no diagnostic or treatment text.
- No device run, no audit run and no physical-device install in this phase.
