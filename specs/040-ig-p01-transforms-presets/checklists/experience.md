# Experience Requirements Quality Checklist: Infinite Geometry — Phase 01

**Purpose**: Unit tests for the requirements of A05-P01 (completeness, privacy, ownership, lifecycle, testability,
performance, release constraints)
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-13; failed items were corrected in the spec before continuing.

## Completeness

- [x] CHK001 Are the four preset kinds and the six controls enumerated? [Spec §FR-A05-110, FR-A05-120] — yes.
- [x] CHK002 Are the phase's MVP and regression fixture each mapped to a requirement and a measurable criterion? [Traceability, SC-A05-101, 102] — yes.
- [x] CHK003 Are bounds stated for every input (order, repetitions, scale, palette, preset index)? [Spec §Edge Cases, data-model] — yes.

## Clarity and consistency

- [x] CHK004 Is it unambiguous how the symmetry order applies to the lattice tilings? [Ambiguity, Spec §FR-A05-111/120 vs data-model] — failed first: the spec said every preset holds an order while the data model said tilings ignore it. Corrected: the order control applies to kaleidoscope and solid; on a tiling it is refused (`a05.order-fixed-by-lattice`) and the state is unchanged.
- [x] CHK005 Are the outcome and its timing defined? [Clarifications Q5] — yes.
- [x] CHK006 Are the motif's seeding and the reseed step defined? [Clarifications Q1] — yes.

## Architecture ownership

- [x] CHK007 Is the reusable part (symmetry) assigned to VisualCore with documentation, baseline and regression? [Spec §FR-A05-101–104] — yes.
- [x] CHK008 Is drawing restricted to the host and the existing renderers? [Spec §FR-A05-132, overrides] — yes.

## iOS lifecycle and recovery

- [x] CHK009 Are context recreation, suspend/resume, teardown/re-entry and restore of a newer version addressed? [Spec §Edge Cases, FR-A05-130] — yes.

## Accessibility and privacy

- [x] CHK010 Are labels, native controls and a canvas description required? [Spec §FR-A05-121] — yes.
- [x] CHK011 Are Reduce Motion and Reduce Flashing both addressed? [Gap, constitution A05 rules] — failed first: only Reduce Motion was named. Corrected: an edge case states compositions are static with no flashing in this phase, so Reduce Flashing needs no change; later animation phases must honour it.
- [x] CHK012 Is the absence of network, accounts and stored personal data stated? [Spec §FR-A05-132] — yes (no network; state is the session snapshot only).

## Testability, performance and release

- [x] CHK013 Is every success criterion tied to a runnable check on host or simulator? [SC-A05-101–106, quickstart] — yes.
- [x] CHK014 Are element and mesh budgets stated as refusals rather than truncation? [Clarifications Q2–Q3] — yes.
- [x] CHK015 Is visibility to people before X-A05 excluded and checkable? [Spec §US3 AC2, FR-A05-131] — yes.

## Notes

- Two items failed on first evaluation (CHK004, CHK011); both corrected in spec.md.
