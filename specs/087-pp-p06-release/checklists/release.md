# Release Requirements Quality Checklist: Physics Playground — Phase 06

**Purpose**: Unit tests for the requirements of A11-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are all Phase 06 deliverables (privacy strings, accessibility, credits, local data migration, tests, crash recovery, build instructions) mapped to requirements? [Spec §Traceability] — yes.
- [x] CHK002 Are the release documents and their required contents enumerated? [FR-A11-604, 620, 622, 623; research D1] — yes.
- [x] CHK003 Are owner and device items stated as such, with no automated substitute? [FR-A11-640, 641] — yes.

## Privacy

- [x] CHK004 Are what is stored, where, how to delete it and that nothing is sent required in the note? [FR-A11-604] — yes.
- [x] CHK005 Is the source scan's pattern list stated? [Clarifications Q3] — yes.

## Truthful claims

- [x] CHK006 Are the refused words consistent with the experience's own interface copy? [Clarifications Q2] — failed at first (the controls' note "not a precise physical measurement" contains a refused word); the clarification now allows that exact note and the panel line, removed before searching.
- [x] CHK007 Is every store claim required to name an existing test? [FR-A11-620, SC-A11-603] — yes.
- [x] CHK008 Are measured performance claims excluded until the device campaign? [Spec §Negative Requirements, Edge Cases] — yes.

## Data and recovery

- [x] CHK009 Are the four sample forms and their expected outcomes defined, with byte-identical refused files? [FR-A11-610, SC-A11-602] — yes.
- [x] CHK010 Is crash recovery defined precisely (failure state, files unchanged, reopen draws)? [FR-A11-611, Clarifications Q5] — yes.
- [x] CHK011 Are all earlier state schemas (1–4) required to restore? [FR-A11-612] — yes.

## Interface and lifecycle

- [x] CHK012 Are the interface journeys listed, with a per-test time bound and a serial chunk? [FR-A11-630, Clarifications Q4] — yes.
- [x] CHK013 Is it stated how canvas gestures are covered when interface tests use native controls? [Spec §Edge Cases] — yes.

## Accessibility

- [x] CHK014 Are the accessibility facts proved so far and the audits pending listed as checklist rows? [FR-A11-623] — yes.

## Release constraints

- [x] CHK015 Are the release build checks named? [FR-A11-631, quickstart] — yes.
- [x] CHK016 Is the per-app listing, pricing and submission excluded (one app)? [Spec §Canonical overrides, Out of Scope] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK006 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
