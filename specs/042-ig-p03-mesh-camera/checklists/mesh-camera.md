# Requirements Quality Checklist: A05-P03 3D mesh and camera

**Purpose**: Unit tests for the requirements of feature 042 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release)
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement-quality criterion satisfied, not that code is done. Under the
owner's standing delegation the lead evaluated every item on 2026-11-13; evaluations are recorded inline.

## Requirement Completeness

- [x] CHK001 Are depth-correct drawing requirements stated for both on-screen and captured output? [Completeness, Spec §FR-A05-301] — yes.
- [x] CHK002 Is the behaviour after a graphics context recreation specified, including resource accounting? [Completeness, Spec §FR-A05-302, SC-A05-303] — yes.
- [x] CHK003 Are all new camera actions named with their parameters and ranges? [Completeness, Spec §FR-A05-310–311, Clarifications] — yes (`camera.pan` 3D, `camera.fov` 30…75).
- [x] CHK004 Is the restore path for states saved by Phases 01 and 02 specified? [Completeness, Spec §FR-A05-314] — yes.
- [x] CHK005 Are accessibility requirements defined for the new controls? [Gap, Spec §FR-A05-315] — FAILED at first (no labels or canvas value named); corrected: labels, identifiers and a field-of-view accessibility value added to FR-A05-315.

## Requirement Clarity

- [x] CHK006 Is "outside the bounding sphere" quantified with a formula? [Clarity, Spec §FR-A05-312] — yes (max(lower, |t| + R + 2·near)).
- [x] CHK007 Is the pan direction defined relative to the camera (view plane) with units? [Clarity, Spec §FR-A05-310, Clarifications] — yes.
- [x] CHK008 Is the probe verdict under lighting defined so it cannot be ambiguous? [Clarity, Clarifications Q5] — yes (larger channel > 0.25).

## Requirement Consistency

- [x] CHK009 Are the 3D distance bounds consistent with Phase 02 (3…12) and the new rule? [Consistency, Spec §FR-A05-312] — yes, the rule only raises the minimum.
- [x] CHK010 Do the 2D presets stay unchanged across requirements and edge cases? [Consistency, Spec §FR-A05-303, Edge Cases] — yes.

## Architecture Ownership

- [x] CHK011 Is it specified which behaviour belongs to VisualCore and which to the experience? [Spec §FR-A05-320–321, Assumptions] — yes (pass and bounds in VisualCore; composition radius from the experience).
- [x] CHK012 Is the host's ownership of the graphics context preserved in the requirements? [Spec §FR-A05-331, Canonical overrides] — yes.

## iOS Lifecycle

- [x] CHK013 Are resize, offscreen export and context recreation all covered as rebuild triggers? [Coverage, Spec §FR-A05-302, Edge Cases] — yes (size change and export in edge cases, recreation in FR-A05-302).

## Testability and Performance

- [x] CHK014 Are all success criteria measurable with explicit thresholds? [Measurability, Spec §SC-A05-301–307] — yes.
- [x] CHK015 Is the GPU memory cost of the new work stated? [Gap, Assumptions] — FAILED at first (no memory statement); corrected: the depth target's cost and its ledger accounting added to Assumptions.
- [x] CHK016 Is the test duration bound stated in line with the owner's short-test rule? [Spec §SC-A05-307] — yes (< 10 s each).

## Privacy and Release

- [x] CHK017 Are network, data collection and imported assets excluded? [Spec §FR-A05-331, Negative Requirements] — yes.
- [x] CHK018 Are documentation, public-API baseline and reference regression required for the framework additions? [Spec §FR-A05-322, SC-A05-306] — yes.

## Notes

- 18 items, 2 failed and corrected in the spec before continuing; `/speckit-implement` reads this state but does not
  change it.
