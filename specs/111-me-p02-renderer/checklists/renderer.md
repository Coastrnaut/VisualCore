# Renderer Requirements Quality Checklist: Molecular Explorer — Phase 02

**Purpose**: Unit tests for the requirements of A15-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK012).

## Completeness

- [x] CHK001 Are all three Phase 02 gates (two display modes, the water and ethanol count fixture, host owns the context) required with measurable outcomes? [Spec §Canonical overrides, SC-A15-201, SC-A15-202] — yes.
- [x] CHK002 Are both display modes defined with their radii, the stick radius and bond visibility? [FR-A15-210, Clarifications Q1] — yes.
- [x] CHK003 Are the camera's steps, limits, default and refusal code stated? [FR-A15-220, Clarifications Q2] — yes.
- [x] CHK004 Are the new state schema, its migration and the actions, controls and fixtures specified? [FR-A15-221, 230, 231, Clarifications Q3, Q4] — yes.

## Clarity and consistency

- [x] CHK005 Is the scene's content (atom items, bond halves from centre to midpoint, colours) defined so counts and bond ends are testable to a stated tolerance? [FR-A15-201, SC-A15-201] — yes (1e-9 Å).
- [x] CHK006 Is the zoom limit shown to keep the camera outside the molecule by arithmetic? [Clarifications Q2] — yes (about 1.3 bounding radii at +4 steps).
- [x] CHK007 Is the draw budget quantified and related to the library's largest scene? [FR-A15-202, Clarifications Q5] — yes (1,500; 74 needed).
- [x] CHK008 Do the camera reset rules agree between the edge cases (molecule change) and the state decision (mode kept, camera reset)? [Spec §Edge Cases, Clarifications Q3] — yes.

## Architecture ownership

- [x] CHK009 Is the core still free of rendering and UI dependencies (scene, camera and state pure, VisualCoreMath only)? [Plan Dependency direction] — yes.
- [x] CHK010 Is the instancing assessment for VisualCoreRendering recorded with its outcome, and no VisualCore change required? [Research D3, Assumptions] — yes.

## iOS lifecycle and edge cases

- [x] CHK011 Are renderer creation, rebuild after context recreation and release together specified? [Plan Lifecycle, Spec §Edge Cases] — yes.
- [x] CHK012 Are Reduce Motion, schema-1 states, single atoms, planar molecules and extreme zoom addressed? [Spec §Edge Cases] — failed (Reduce Motion was not addressed); an edge case now states that every camera change cuts in one frame.

## Accessibility and privacy

- [x] CHK013 Are values for every new control and the mode in the canvas description required, and are display radii labelled as conventions? [FR-A15-230, Clarifications Q1, Q4] — yes.
- [x] CHK014 Are no network, no textures and no VisualCore change stated? [Negative Requirements] — yes.

## Testability and performance

- [x] CHK015 Can every success criterion be checked without a device? [SC-A15-201–205, quickstart] — yes.
- [x] CHK016 Are mesh counts and items bounded and no performance figures claimed? [Plan Technical Context] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
