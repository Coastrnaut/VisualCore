# Import and Review Requirements Quality Checklist: Molecular Explorer — Phase 05

**Purpose**: Unit tests for the requirements of A15-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer); three items failed and were
corrected before this record (CHK008, CHK009, CHK013).

## Completeness

- [x] CHK001 Is every parser refusal reason mapped to a user-visible sentence, plus the size limit and an unreadable file? [Spec §Clarifications Q2, FR-A15-503]
- [x] CHK002 Is the order "size checked before reading" stated as a requirement, not an implementation hint? [Spec §FR-A15-502, Negative Requirements]
- [x] CHK003 Are the import actions, their value ranges and their refusal code defined? [Spec §Clarifications Q1, contracts/import.md]
- [x] CHK004 Is the state schema change (4) and its migration from 1–3 specified? [Spec §Clarifications Q1, plan §Migration]
- [x] CHK005 Is the review document's content (value, units, source, license, statements) and its comparison rule specified? [Spec §Clarifications Q5, FR-A15-520]

## Privacy and ownership

- [x] CHK006 Is it stated that no permission, usage description, network or storage outside the experience's folder is involved? [Spec §FR-A15-501, Negative Requirements]
- [x] CHK007 Is the untrusted comment line excluded from display, and is the title sanitization rule (characters, length, fallback) defined? [Spec §Clarifications Q3, Edge Cases]
- [x] CHK008 Is the behaviour defined when the stored copy cannot be written? [Gap → Edge Cases] — failed (only in the plan); the spec's edge cases now state it with its message.

## iOS lifecycle

- [x] CHK009 Is the behaviour defined when the picker returns while the experience is not active? [Gap → Edge Cases] — failed (not stated); now an edge case.
- [x] CHK010 Is the security-scoped access window (start before reading, stop after) part of the plan's lifecycle? [Plan §Lifecycle]
- [x] CHK011 Is reopening with the import in the saved state, and with the title file missing, specified? [Spec §US1 AC2, Edge Cases]

## Testability and performance

- [x] CHK012 Are the fuzz corpus size, seeds, mutations and pass rule stated measurably? [Spec §Clarifications Q4, SC-A15-503]
- [x] CHK013 Are import success and refusal announcements specified for assistive technologies? [Gap → FR-A15-540] — failed (only the control's label was required); FR-A15-540 now requires both announcements.
- [x] CHK014 Is the leak fixture measurable (rounds, what is compared, baseline)? [Spec §SC-A15-505, research D6]
- [x] CHK015 Are test durations bounded (each under 10 s) without wall-clock assertions? [Spec §SC-A15-506]

## Release constraints

- [x] CHK016 Is the claim-word list explicit and is the shared copy-claims check named as evidence? [Spec §Clarifications Q5, quickstart step 3]
- [x] CHK017 Is it stated that release work (dossier, acknowledgements wording) stays for A15-P06? [Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
