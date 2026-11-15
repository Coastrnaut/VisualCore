# Interaction Requirements Quality Checklist: Light Maze — Phase 02

**Purpose**: Unit tests for the requirements of A13-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); no item failed (the drag action was
already simplified in the clarification session).

## Completeness

- [x] CHK001 Are both Phase 02 gates (snapped drag and rotate; bounded loops) required with measurable outcomes? [Spec §Canonical overrides, SC-A13-202, 203, 205] — yes.
- [x] CHK002 Are tap, drag and rotate each defined with what they change and what they leave alone? [FR-A13-201–203, Clarifications Q1–Q3] — yes.
- [x] CHK003 Are the glow, ring and outline geometry stated? [FR-A13-210, 211, Clarifications Q4] — yes.
- [x] CHK004 Are the loop fixtures named (mirror back to emitter, prism branches meeting, spiral to the cap)? [FR-A13-220, Clarifications Q5] — yes.

## Clarity

- [x] CHK005 Are the snap distance (0.35 cell) and snap angle (45°) quantified? [Clarifications Q2, Q3] — yes.
- [x] CHK006 Is the cell resolution of a point defined (inverse board camera, floor)? [Clarifications Q1] — yes.
- [x] CHK007 Are the gesture priorities stated? [Clarifications Q3, contract] — yes.

## Consistency

- [x] CHK008 Do gestures use only actions the native controls send? [FR-A13-204, Clarifications Q2] — yes (select and turn).
- [x] CHK009 Are glow limits consistent between the spec, the contract and the success criteria? [SC-A13-204, contract] — yes.

## Architecture ownership

- [x] CHK010 Is reuse of VisualCore's recognizers and arbiter required, with no VisualCore change? [Plan Constitution Check II, II-a] — yes.
- [x] CHK011 Is the beam drawn only from the tracer's segments, never deciding the solved state? [FR-A13-210, Negative Requirements] — yes.

## iOS lifecycle and accessibility

- [x] CHK012 Are context loss, suspension (touch state reset) and Reduce Motion / Reduce Flashing addressed? [Edge Cases, plan Lifecycle] — yes.
- [x] CHK013 Are non-colour cues and rate-limited spoken changes required? [FR-A13-211, 212] — yes.

## Testability, privacy and performance

- [x] CHK014 Can every success criterion be checked without a device? [SC-A13-201–206, quickstart] — yes.
- [x] CHK015 Are no permission, no network and no new content stated? [Negative Requirements, Constitution VIII] — yes.
- [x] CHK016 Are rendering costs bounded (one rebuild per change, one glow primitive per segment) without timing claims? [Plan Technical Context] — yes.

## Notes

- 16 items evaluated on 2026-11-15; none failed. `/speckit-implement` reads these markers and does not change them.
