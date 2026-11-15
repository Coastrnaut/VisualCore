# Water Effects Requirements Quality Checklist: Digital Aquarium — Phase 04

**Purpose**: Unit tests for the requirements of A09-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); two items failed and were corrected
in the spec before this record (CHK013, CHK016).

## Completeness

- [x] CHK001 Are all four MVP elements (bubbles, caustics, depth layers, environmental particles) required? [Spec §FR-A09-401–411] — yes.
- [x] CHK002 Is the regression fixture for missing or unsupported content required at catalog read, restore and drawing? [Spec §FR-A09-430, US4] — yes.
- [x] CHK003 Are the description elements enumerated? [Spec §FR-A09-420] — yes.
- [x] CHK004 Are the announced changes enumerated with their sentences? [Spec §FR-A09-421, Clarifications Q4] — yes.

## Clarity and measurability

- [x] CHK005 Are bubble numbers quantified (vents, rate, speed, wobble, limit)? [Spec §FR-A09-401, Clarifications Q1] — yes.
- [x] CHK006 Are depth amounts quantified (assignment, scales, tints, order)? [Spec §FR-A09-410, Clarifications Q2] — yes.
- [x] CHK007 Are caustics strength per lighting level and its time rate stated? [Clarifications Q3] — yes.
- [x] CHK008 Is the announcement interval stated? [Spec §FR-A09-421] — yes (3 s).
- [x] CHK009 Are the success criteria measurable (counts, order, size ratio, frame difference, refusals)? [Spec §SC-A09-401–406] — yes.

## Consistency

- [x] CHK010 Is Reduce Motion handled consistently for bubbles, motes and caustics? [Spec §FR-A09-404, 411] — yes.
- [x] CHK011 Are pause and suspension consistent with earlier phases (effects hold)? [Spec §FR-A09-403] — yes.
- [x] CHK012 Is the saved state unchanged by this phase? [Spec §FR-A09-403, SC-A09-402] — yes.

## Edge cases and recovery

- [x] CHK013 Is recovery of the light pattern after a context loss or resize specified? [Gap] — failed; corrected in FR-A09-411.
- [x] CHK014 Are a habitat without vents, lighting changes, many simultaneous changes and a small canvas covered? [Spec §Edge Cases] — yes.
- [x] CHK015 Is the fallback when the light pattern cannot be prepared specified? [Spec §FR-A09-411, US2-4] — yes.
- [x] CHK016 Is the announcer's behaviour on opening and restoring specified? [Gap] — failed; corrected in FR-A09-421 (first frame announces nothing).

## Architecture, privacy, performance and release

- [x] CHK017 Is the work app-local with no second renderer or context? [Spec §Negative Requirements, Assumptions] — yes.
- [x] CHK018 Is graphics-context ownership kept in the host? [Spec §Canonical overrides] — yes.
- [x] CHK019 Does the phase add no data collection, permission or network? [Spec §Negative Requirements] — yes.
- [x] CHK020 Is per-frame work bounded (48 bubbles, 24 motes, one pass)? [Spec §FR-A09-401–402; plan] — yes.
- [x] CHK021 Is flashing excluded? [Spec §Negative Requirements] — yes.
- [x] CHK022 Are test durations bounded? [Spec §SC-A09-407] — yes.
- [x] CHK023 Is the deferral of quality levels to A09-P05 explicit? [Spec §Canonical overrides, Assumptions] — yes.

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
