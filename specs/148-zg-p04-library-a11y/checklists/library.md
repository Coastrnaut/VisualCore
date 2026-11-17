# Library and Accessibility Requirements Quality Checklist: Digital Zen Garden — Phase 04

**Purpose**: Unit tests for the requirements of A20-P04 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are the library's file layout, caps, name rules and messages specified? [Spec §Q1, data-model] — yes.
- [x] CHK002 Are every refusal of a saved garden and its handling specified? [Spec §FR-A20-402, Q1] — yes.
- [x] CHK003 Are the accessibility labels, description, announcements and large-text behaviour specified? [Spec §FR-A20-403, Q3] — yes.
- [x] CHK004 Is the still's size, location, lifetime and destination specified? [Spec §FR-A20-405, Q4] — yes.

## Clarity and measurability

- [x] CHK005 Is "bounded" quantified for the history (count and bytes)? [Spec §SC-A20-402, Q2] — yes (100 commands, 2,457,600 bytes).
- [x] CHK006 Is the large-text check measurable (height grows, width fits)? [Spec §Q3] — yes.

## Consistency

- [x] CHK007 Is the opened garden's digest consistent with the document-only digest of A20-P02? [Spec §Q5, facts] — yes.

## Edge cases

- [x] CHK008 Are a failed save and deleting the open garden's saved copy covered? [Spec §Edge Cases] — failed (not covered); the edge cases now keep the previous file and the open garden.
- [x] CHK009 Are empty, long and duplicate names, the cap, damaged files and a failed still covered? [Spec §Edge Cases, Q1] — yes.

## Privacy and release

- [x] CHK010 Is the permission limited to the share sheet's add-only string, with no PhotoKit and no network? [Spec §FR-A20-406, Q4] — yes.
- [x] CHK011 Is the registration's permission word named so the usage-description step stays exact? [Spec §Q4, plan] — yes.

## Architecture and lifecycle

- [x] CHK012 Is the library kept in the experience's own storage and quota, with the reason for not using `NamedLibrary`? [Spec §Q1, research D1] — yes.
- [x] CHK013 Is the history restart on open specified? [Spec §Edge Cases, Q5] — yes.

## Testability and performance

- [x] CHK014 Is the long-history fixture bounded in size so it stays a short test? [Plan §Technical Context] — yes.
- [x] CHK015 Are system accessibility audits deferred to the device campaign? [Spec §Q3] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
