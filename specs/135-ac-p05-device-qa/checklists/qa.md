# QA Requirements Quality Checklist: Ambient Clock — Phase 05

**Purpose**: Unit tests for the requirements of A18-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Is the still rule defined with every condition (motion, reduce motion, seconds, fade)? [Clarification Q2] — yes.
- [x] CHK002 Does the cache key list everything the picture depends on, so no stale picture can show? [Clarification Q2, research D2] — yes.
- [x] CHK003 Is every campaign row given a device class, procedure, threshold and status? [Clarification Q3, Spec §FR-A18-504] — yes.

## Architecture ownership

- [x] CHK004 Is the cache's placement in VisualCoreRendering justified by the rule that experiences make no graphics calls, with existing scenes unchanged? [Clarification Q1, Spec §FR-A18-503] — yes.

## iOS lifecycle

- [x] CHK005 Are context loss and resize with a cached picture addressed? [Spec §Edge Cases, contracts/qa.md] — yes.

## Consistency

- [x] CHK006 Do the spec's success criterion and the clarification agree on the number of campaign rows? [Spec §SC-A18-503, Clarification Q3] — failed (the criterion said at least eight, the clarification names ten); SC-A18-503 now names AC-D1 to AC-D10.

## Release and device constraints

- [x] CHK007 Are device actions, measurements and audits barred before ImplementationLock-100, and is D3 left on iPadOS 26.5? [Spec §Negative Requirements, Assumptions] — yes.
- [x] CHK008 Is every store claim tied to a test or a campaign row? [Spec §US2] — yes.

## Testability

- [x] CHK009 Are draw counts and frame identity measurable for the still, changed and moving cases? [SC-A18-501, 502] — yes.
- [x] CHK010 Are the interface tests bounded (under 60 s) and placed in a named serial chunk? [Clarification Q4, SC-A18-504] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
