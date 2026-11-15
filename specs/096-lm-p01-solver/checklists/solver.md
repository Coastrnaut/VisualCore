# Solver Requirements Quality Checklist: Light Maze — Phase 01

**Purpose**: Unit tests for the requirements of A13-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are both Phase 01 gates (20 handcrafted levels; incidence equals reflection) required with measurable outcomes? [Spec §Canonical overrides, SC-A13-101, 103] — yes.
- [x] CHK002 Are all five tile kinds and their behaviour defined? [FR-A13-110, Clarifications Q2] — yes.
- [x] CHK003 Are the 2D ray, segment, hit and reflection interfaces stated with their rules (parallel, end points, non-finite, excluded segment, minimum distance)? [FR-A13-101–103, Clarifications Q1, contracts/api.md] — yes.
- [x] CHK004 Are the level content, its solutions, fixtures and license records required? [FR-A13-113, 114, Clarifications Q4] — yes.

## Architecture ownership

- [x] CHK005 Is the split between generic ray casting (VisualCore) and board rules (experience) stated? [Spec §Canonical overrides, plan Dependency direction] — yes.
- [x] CHK006 Is the beam required to come only from the CPU tracer, never a shader? [FR-A13-120, Negative Requirements] — yes.

## Clarity and consistency

- [x] CHK007 Are the caps (bounces, segments, branches) and the cycle rule quantified? [Clarifications Q3, data model] — yes.
- [x] CHK008 Do the target rules agree between the edge cases and the clarifications? [Spec §Edge Cases, Clarifications Q2] — failed ("the back of a target" implied a dead side while targets light from any side); corrected.
- [x] CHK009 Is the reflection tolerance stated numerically? [Clarifications Q1, research D2] — yes (1e-12).

## iOS lifecycle

- [x] CHK010 Are context loss, backgrounding and redraw-from-state required? [FR-A13-120, Edge Cases] — yes.

## Privacy and release constraints

- [x] CHK011 Are no permission, no network and original-only content stated? [Negative Requirements, FR-A13-114] — yes.
- [x] CHK012 Is the candidate registration (unavailable until X-A13) and the saved-state schema with refusals required? [FR-A13-122] — yes.

## Testability and measurability

- [x] CHK013 Can every success criterion be checked by a host or simulator test? [SC-A13-101–106, quickstart] — yes.
- [x] CHK014 Are the accessibility requirements (labels, values, spoken description) stated for every control? [FR-A13-121] — yes.

## Performance

- [x] CHK015 Are tracing bounds and "never per frame" stated without timing claims? [plan Technical Context] — yes.
- [x] CHK016 Is the reference regression for the VisualCore change scheduled (X-A13) rather than skipped? [Spec §Canonical overrides, constitution II-a] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
