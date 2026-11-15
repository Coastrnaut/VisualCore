# Camera and Renderer Requirements Quality Checklist: Tiny Worlds — Phase 02

**Purpose**: Unit tests for the requirements of A12-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); two items failed and were corrected
before this record (CHK008, CHK009).

## Completeness

- [x] CHK001 Are both manual phase gates (constrained orbit camera; LOD indices in bounds) mapped to requirements? [Spec §Traceability, FR-A12-210, 222] — yes.
- [x] CHK002 Are the camera limits, clearance and its sampling quantified? [Clarifications Q3, FR-A12-210] — yes (10°…75°, 10…30 m, 0.5 m over 9 samples within 1 m).
- [x] CHK003 Are the three detail levels and their mapping to quality levels defined? [Clarifications Q5, FR-A12-222] — yes.

## Architecture ownership

- [x] CHK004 Is it stated which additions are generic (colour stream, ray intersection) and which are app-local (policy, colouring, levels, ground pick)? [Spec §Canonical overrides, plan] — yes.
- [x] CHK005 Is the public API of the generic additions specified with refusals? [contracts/api.md, Clarifications Q1–Q2] — yes.
- [x] CHK006 Is "existing output unchanged" stated measurably for meshes without colours? [FR-A12-201, SC-A12-204] — yes (pixel-identical).

## Determinism and testability

- [x] CHK007 Are ray-intersection edge cases (grazing, parallel, inside start, degenerate) defined? [Clarifications Q2, Edge Cases] — yes.
- [x] CHK008 Is the colour-match tolerance quantified? [SC-A12-204] — failed at first ("the stated pixel tolerance" was never stated); corrected to ±8 of 255 per channel.
- [x] CHK009 Is the ground-pick accuracy quantified? [US3 AC1] — failed at first ("a small tolerance"); corrected to 1 mm.
- [x] CHK010 Is it stated that the terrain digests and fixtures are unaffected by colours and levels? [Clarifications Q4–Q5] — yes.

## Interface, accessibility and lifecycle

- [x] CHK011 Does every gesture have a control alternative, and is the check defined? [FR-A12-211, SC-A12-205] — yes.
- [x] CHK012 Are Reduce Motion (including mid-ease) and the speech rate limit defined? [FR-A12-212, 213, Edge Cases] — yes.
- [x] CHK013 Are context loss and level changes defined not to change the world? [Edge Cases, FR-A12-222, plan Lifecycle] — yes.

## Privacy and data

- [x] CHK014 Is the saved state unchanged (schema 1) with the view kept policy-valid on restore, and no permission or network added? [Clarifications Q5, Edge Cases, Negative Requirements] — yes.

## Performance

- [x] CHK015 Are sample and geometry bounds quantified without measured performance claims? [plan Technical Context] — yes.

## Release constraints

- [x] CHK016 Is the reference regression for the VisualCore change deferred to X-A12 and the experience kept a candidate? [Spec §Canonical overrides] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK008 and CHK009 corrected in spec.md before marking. `/speckit-implement` reads
  these markers and does not change them.
