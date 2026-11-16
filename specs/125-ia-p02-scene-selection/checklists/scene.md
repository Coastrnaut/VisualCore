# Scene and selection checklist: Interactive Anatomy — Phase 02

**Purpose**: unit tests for the requirements of the region scene, picking, layers, camera and budgets (feature 125).
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it does not mean the work is done.
Evaluated by the lead under the owner's standing delegation on 2026-11-16. Failing items were corrected in the
artifacts before they were ticked.

## Requirement Completeness

- [x] CHK001 Are all 20 declared meshes required to be built, validated and budgeted at every quality level? [Spec §FR-A17-201, SC-A17-201]
- [x] CHK002 Are the actions, their value ranges and every rule refusal named? [Spec §Clarifications Q4; contracts/scene.md]
- [x] CHK003 Are the materials, the selection highlight and the backdrop specified with values? [Spec §Clarifications Q5]
- [x] CHK004 Is the saved state's content and schema version defined, with its refusals? [Spec §FR-A17-210, Q5]

## Requirement Clarity

- [x] CHK005 Is "nearest visible structure" defined, including the tie rule and the miss behaviour? [Spec §FR-A17-204]
- [x] CHK006 Is "frames it" quantified (the bounding sphere inside the view; fit factor 1.25 on the narrower axis)? [Spec §FR-A17-208, Q3]
- [x] CHK007 Are the camera's step sizes and limits stated as numbers? [Spec §Q3]
- [x] CHK008 Are the budgets quantified per level (triangles, draws, labels)? [Spec §FR-A17-209, Q1]

## Requirement Consistency

- [x] CHK009 Do the hidden-structure rules agree between picking, the list and the selection (no path selects a hidden structure)? [Spec §FR-A17-205, 207, Story 3]
- [x] CHK010 Is the phase boundary with A17-P03 and A17-P04 (isolate, ghosts, saved view, labels, accessibility review) stated consistently in the assumptions, the clarifications and the negative requirements? [Spec §Assumptions, Q5]

## Scenario and Edge Case Coverage

- [x] CHK011 Are context loss, resize and a quality level change covered with what is kept? [Spec §Edge Cases; corrected: the quality level change was added]
- [x] CHK012 Are all layers hidden, boundary taps, an unbuildable mesh and a restored selection on a hidden layer covered? [Spec §Edge Cases; corrected: the restored selection was added]
- [x] CHK013 Is the treatment of gestures other than a single tap defined? [Spec §Edge Cases; corrected: drags and multi-touch are ignored in this phase]

## Architecture, Lifecycle, Privacy and Release

- [x] CHK014 Is graphics-context ownership kept in the host, with the experience's GPU objects made, rebuilt and released together? [Spec §FR-A17-202; plan §Lifecycle]
- [x] CHK015 Are privacy constraints stated (no network, no asset, state only in the session snapshot)? [Spec §Negative Requirements, FR-A17-210]
- [x] CHK016 Is the registration a candidate inside the one app, with standard scenarios and fixtures, and no standalone target? [Spec §FR-A17-210; Canonical overrides]
- [x] CHK017 Are the test time limits and runtime stated (under 10 s, iOS 27)? [Spec §SC-A17-205]

## Notes

- `/speckit-implement` reads this checklist's state; it does not change the markers.
