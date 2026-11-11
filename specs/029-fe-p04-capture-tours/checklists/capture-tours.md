# Capture, Tours and Cost Requirements Checklist: Fractal Explorer — Phase 04

**Purpose**: Unit-test the Phase 04 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release) before tasks.
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md)

**Ownership**: reviewer-owned. `[x]` means the reviewer judged the requirement-quality criterion satisfied, not that
code is done. Depth: standard; audience: reviewer. Clarifying questions were skipped: the prompt names the focus areas.

## Requirement Completeness

- [x] CHK001 Are the cost formula's factors, reference and level thresholds all stated? [Completeness, Spec §US1 AC2, FR-A03-401]
- [x] CHK002 Are capture size, aspect, frozen animation and the share path specified? [Completeness, Spec §US2 AC1, clarification 1]
- [x] CHK003 Are the tour list, stops, flight and hold durations and the stop conditions specified? [Completeness, Spec §US3, clarification 2]
- [x] CHK004 Is the spoken/announced behavior of tour captions specified for VoiceOver users? [Gap → amended: FR-A03-406]

## Requirement Clarity

- [x] CHK005 Is "relative" cost unambiguous (no time unit, reference named)? [Clarity, Spec §US1 AC2, Negative requirements]
- [x] CHK006 Is the flight path defined precisely enough to test "target stays in view"? [Clarity, clarification 2, SC-A03-402]
- [x] CHK007 Is the precision-limited capture size rule quantified? [Clarity, clarification 1]

## Requirement Consistency

- [x] CHK008 Is the cap range consistent between the control (50…10,000) and the domain cap range (1…10,000)? [Consistency, Spec §US1 AC1; bookmarks may hold caps below 50 and keep them]
- [x] CHK009 Do the tour's precision rules agree with Phase 02's clamp and banner? [Consistency, Spec §US3 AC4]

## Architecture Ownership

- [x] CHK010 Is each reusable piece (cost, flight/timeline, still capture) assigned to a VisualCore module with tests and docs? [Spec §FR-A03-401–403, plan]
- [x] CHK011 Is the decision not to change A02 now, with a follow-up, recorded? [Spec §FR-A03-403, plan Migration]
- [x] CHK012 Is the new VisualCoreRendering → VisualCorePersistence dependency justified against the package rules? [Plan Project Structure]

## Privacy and Release

- [x] CHK013 Is saving restricted to the share sheet with the Photos add-only usage text? [Spec §FR-A03-405, Negative requirements]
- [x] CHK014 Are temporary capture files' lifetimes (replace, leave, launch) specified? [Spec §US2 AC4]

## iOS Lifecycle

- [x] CHK015 Is the tour's behavior when the app moves to the background, or the screen is left, specified? [Gap → amended: Edge Cases]
- [x] CHK016 Is Reduce Motion behavior for tours specified? [Spec §US3 AC2]

## Testability and Performance

- [x] CHK017 Can each success criterion be checked automatically on host or simulator? [Measurability, SC-A03-401…406]
- [x] CHK018 Is the fixture's tolerance band ([1, 2] × true spacing) justified by the advisor's definition? [Spec §US4, research R6]
- [x] CHK019 Is the behavior when the canvas has no size yet defined for capture and the cost line? [Gap → amended: Edge Cases]

## Notes

- Review 2026-11-11 (delegated reviewer, CLAUDE.md §2): CHK004, CHK015 and CHK019 found gaps; the spec was amended,
  then the items were checked. `/speckit-implement` reads these markers but does not change them.
