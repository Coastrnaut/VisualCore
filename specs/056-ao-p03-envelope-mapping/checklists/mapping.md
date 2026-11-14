# Mapping Requirements Quality Checklist: Audio Odyssey — Phase 03

**Purpose**: Unit tests for the requirements of A07-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK004).

## Completeness

- [x] CHK001 Are both phase gates (manual speed, easing, reduced motion; source switching keeps the context) required? [Spec §FR-A07-301–303, 320] — yes.
- [x] CHK002 Are all three worlds' two responses and their default mappings specified? [Spec §FR-A07-311, Clarifications Q4] — yes.
- [x] CHK003 Are reset, per-world persistence and migration of older states specified? [Spec §FR-A07-312, 330; Edge Cases] — yes.

## Clarity and consistency

- [x] CHK004 Do the envelope channels in the requirements match those the mapping can choose? [Spec §FR-A07-310, data-model.md] — failed at first (the data model offered an "overall" channel the requirement did not name); FR-A07-310 and the entity now include the derived overall channel.
- [x] CHK005 Are speed range, step, easing factors and calm caps quantified? [Clarifications Q2, Q3; ComfortLimits] — yes.
- [x] CHK006 Is the relation between in-app calm motion and the system Reduce Motion defined? [Spec §FR-A07-303, Clarifications Q5] — yes (either turns it on).

## Architecture ownership

- [x] CHK007 Is the slice kept in the experience, with no VisualCore change, and the reason stated? [Spec overrides, Plan Constitution Check II] — yes.
- [x] CHK008 Are the envelope and responses specified as pure domain logic testable without audio hardware? [Clarifications Q1, Plan Testing] — yes.

## iOS lifecycle and privacy

- [x] CHK009 Is the continuity of the host context across source switches required and measurable? [Spec §FR-A07-320, SC-A07-305] — yes.
- [x] CHK010 Does the phase add no permission, data collection or network use? [Spec §FR-A07-340] — yes.

## Testability and performance

- [x] CHK011 Is every success criterion tied to a runnable check? [SC-A07-301–306, quickstart] — yes.
- [x] CHK012 Is "gentle takes longer" quantified? [SC-A07-302] — yes (at least twice brisk).
- [x] CHK013 Are bounds and per-frame step limits defined for every response? [Spec §FR-A07-311, data-model.md] — yes.

## Release constraints

- [x] CHK014 Are audio-driven camera motion and health or measurement claims excluded? [Spec §FR-A07-340, Negative Requirements] — yes.
- [x] CHK015 Is the saved-state version change and its migration path specified? [Spec §FR-A07-330, Plan Migration] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK004 corrected in spec.md before marking. `/speckit-implement` reads these
  markers and does not change them.
