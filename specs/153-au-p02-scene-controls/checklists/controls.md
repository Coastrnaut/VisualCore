# Controls Requirements Quality Checklist: Aurora — Phase 02

**Purpose**: Unit tests for the requirements of A21-P02 (completeness, privacy, ownership, lifecycle, testability,
performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) judged the requirement's quality
satisfied, not that work is done. One item failed and was corrected before this record (CHK006).

## Completeness

- [x] CHK001 Is every control listed with its id, range, step kind and default where one exists? [Spec Clarifications Q1, data-model] — yes.
- [x] CHK002 Is the brightness limit's range, default and point of application stated? [Q1, Q2] — yes (0.2…0.72, default 0.6, after compositing).
- [x] CHK003 Is the change between presets quantified (duration, easing, interruption, Reduce Motion)? [Spec §FR-A21-204, Q3] — yes.
- [x] CHK004 Are the registration items enumerated (catalog entry, registry candidate, project product, tests)? [Q5] — yes.

## Clarity and measurability

- [x] CHK005 Is "no pixel brighter than the limit" measurable with a stated rounding allowance and sample set? [Spec §SC-A21-202, Q2, contract] — yes (limit + 1/255; every preset, three limits, start, middle and end of each change).
- [x] CHK006 Is the behaviour defined for a snapshot that cannot be restored? [Gap, data-model] — failed; data-model and the contract now refuse a newer, damaged or refused snapshot with the state unchanged.
- [x] CHK007 Is the state separated from presentation (hidden controls not saved)? [Q1, research D3] — yes.

## Lifecycle and ownership

- [x] CHK008 Are context loss, resize and teardown covered, with the rebuild from state? [Spec §FR-A21-207, plan lifecycle] — yes.
- [x] CHK009 Is rendered time tied to frame deltas so a background return never jumps? [Q4, A21-P01] — yes.
- [x] CHK010 Is the scene protocol the only path for GL work? [Spec §FR-A21-207, Negative Requirements] — yes.

## Accessibility, privacy and release

- [x] CHK011 Does every control carry a spoken label and value, and is the restore action reachable while hidden? [Spec §FR-A21-201, 205, Edge Cases] — yes.
- [x] CHK012 Is availability to a person excluded until X-A21? [Spec §FR-A21-206] — yes.
- [x] CHK013 Is no permission, network or recording introduced? [Spec §Negative Requirements] — yes.
- [x] CHK014 Are unit tests bounded in time? [Spec §SC-A21-204] — yes.
