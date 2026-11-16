# Selection Requirements Quality Checklist: Molecular Explorer — Phase 03

**Purpose**: Unit tests for the requirements of A15-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK011).

## Completeness

- [x] CHK001 Are all three Phase 03 gates (touch orbit, pan, zoom and picking; selection correct for camera and occlusion; host owns the context) required with measurable outcomes? [Spec §Canonical overrides, SC-A15-301, SC-A15-302] — yes.
- [x] CHK002 Are the gesture thresholds and their mapping to camera steps quantified? [FR-A15-301, Clarifications Q1] — yes.
- [x] CHK003 Are the pan's step size, limits, action and reset stated? [FR-A15-302, Clarifications Q2] — yes.
- [x] CHK004 Are the picking rule, the actions, their ranges and refusals specified? [FR-A15-310, 311, Clarifications Q3] — yes.

## Clarity and consistency

- [x] CHK005 Is the occlusion policy (nearest drawn sphere along the line of sight, mode radius) unambiguous and testable over stated camera positions? [FR-A15-310, SC-A15-301] — yes (eight positions, both modes, five molecules).
- [x] CHK006 Is the label rule quantified (box size, offset, order, overlap and off-canvas rules)? [FR-A15-320, Clarifications Q4] — yes.
- [x] CHK007 Are the bond styles quantified for every order and for inferred bonds, with the side direction defined? [FR-A15-321, Clarifications Q4] — yes.
- [x] CHK008 Do the selection rules agree between edge cases (molecule change clears, mode change keeps) and the state decision? [Spec §Edge Cases, Clarifications Q5] — yes.

## Architecture ownership

- [x] CHK009 Are picker, labels, bond styles, pan and state pure core code, and gestures a pure value fed by synthetic events in tests? [Plan Project Structure, Constitution IV] — yes.
- [x] CHK010 Is reuse of the arbiter, recognizers, rays and the overlay slot required with no upstream change? [Assumptions, Plan Technical Context] — yes.

## iOS lifecycle and edge cases

- [x] CHK011 Are suspension and teardown during a gesture addressed? [Spec §Edge Cases, Plan Lifecycle] — failed (only the plan mentioned `reset()`); an edge case now states that touches are forgotten and nothing more is sent.
- [x] CHK012 Are taps that miss, tiny or fast gestures, overlapping atoms, hidden selected atoms, pan limits, inferred bonds and schema-2 states addressed? [Spec §Edge Cases] — yes.

## Accessibility and privacy

- [x] CHK013 Does every gesture have a native control, and is information never carried by colour alone? [FR-A15-301, 311, 321] — yes.
- [x] CHK014 Are the panel's lines, the description suffix and the announcement rule (at most one per action) specified? [FR-A15-322, 323, Clarifications Q5] — yes.

## Testability and performance

- [x] CHK015 Can every success criterion be checked without a device? [SC-A15-301–305, quickstart] — yes.
- [x] CHK016 Are picking, label and stick counts bounded and within the draw budget, with no performance figures claimed? [Plan Technical Context] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
