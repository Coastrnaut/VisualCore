# Renderer Requirements Quality Checklist: Oscilloscope Studio — Phase 02

**Purpose**: Unit tests for the requirements of A08-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK007).

## Completeness

- [x] CHK001 Are all three manual gates (XY from stereo input; trigger with flat line and missing crossing; context in the host) required? [Spec overrides, FR-A08-211, 213, 220] — yes.
- [x] CHK002 Are the gaps built here (G-DECIMATION, G-TRACESTRIP, G-XYMODE moved from A08-P03) and what stays later named? [Spec overrides, Out of Scope] — yes.
- [x] CHK003 Is the saved-state change (schema 2, migration from schema 1) required? [FR-A08-212, Clarifications Q5] — yes.

## Clarity

- [x] CHK004 Is the column rule (assignment of samples to columns, identity when the window fits, non-finite samples) defined precisely? [FR-A08-201, Clarifications Q2, data-model] — yes.
- [x] CHK005 Are the XY mapping (scale, clamp, square area, point order) and the stereo rule defined? [FR-A08-211, Clarifications Q4] — yes.
- [x] CHK006 Is the shape bound (8,192 points), its truncation and the width rule stated? [Edge Cases, Clarifications Q1] — yes.

## Consistency

- [x] CHK007 Do the XY fallback scenario and the saved-view rule agree? [Story 1 AC3, Clarifications Q5] — failed at first (AC3 required a new choice to return to XY while the saved view stays XY); corrected: the chosen view stays XY and a stereo source shows XY again.
- [x] CHK008 Is the requirement that existing shapes stay unchanged consistent with adding the new shape case? [FR-A08-203, research D1] — yes.

## Architecture ownership

- [x] CHK009 Is the split between VisualCore (reduction, shape, renderer) and the experience (zig-zag and XY points, view state, copy) explicit? [Plan Constitution Check II, Project Structure] — yes.
- [x] CHK010 Is drawing restricted to the host's existing 2D renderer (no second path or context)? [FR-A08-202, Negative Requirements] — yes.

## iOS lifecycle

- [x] CHK011 Is it stated that the lifecycle of A08-P01 is unchanged and per-frame nodes are replaced, not accumulated? [Plan Lifecycle] — yes.

## Privacy and release constraints

- [x] CHK012 Are no new data, permission or network use and no calibrated phase claims stated? [FR-A08-230, Negative Requirements] — yes.

## Testability and performance

- [x] CHK013 Is every success criterion tied to a runnable check with tolerances (pixel parity 1 %, column extremes exact)? [SC-A08-201–205, quickstart] — yes.
- [x] CHK014 Is the geometry bound per frame (≤ 2 N points per channel, N ≤ pixel columns) stated without wall-clock assertions? [FR-A08-210, Plan Technical Context] — yes.
- [x] CHK015 Are the trigger fixture states (auto "no trigger", normal "waiting") defined for both a flat line and a missing crossing? [Story 3, FR-A08-213] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK007 corrected in spec.md before marking. `/speckit-implement` reads these
  markers and does not change them.
