# Terrain Requirements Quality Checklist: Tiny Worlds — Phase 01

**Purpose**: Unit tests for the requirements of A12-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); two items failed and were corrected
before this record (CHK007, CHK011).

## Completeness

- [x] CHK001 Are both manual phase gates (three presets; same seed → identical mesh hashes) mapped to requirements? [Spec §Traceability, FR-A12-110–112] — yes.
- [x] CHK002 Are all three preset recipes specified with size, resolution, noise settings, shaping rule, height range and palette? [Clarifications Q3] — yes.
- [x] CHK003 Are the actions, their ranges and the refusal code defined? [Clarifications Q4] — yes.

## Architecture ownership

- [x] CHK004 Is it stated which pieces are generic VisualCore code (noise, height field) and which are app-local (recipes, palettes, view, licenses)? [Spec §Canonical overrides, FR-A12-101–113; plan Dependency direction] — yes.
- [x] CHK005 Is the public API of the generic code specified with its refusal rules and documentation requirement? [contracts/api.md, FR-A12-103] — yes.
- [x] CHK006 Is "existing meshes and digests unchanged" stated for the VisualCore change? [FR-A12-103] — yes.

## Determinism and testability

- [x] CHK007 Are the digest fixture counts consistent (presets × seeds and seed pairs)? [SC-A12-101] — failed at first ("9 seed pairs per preset" with 3 seeds); corrected to 3 pairs per preset.
- [x] CHK008 Is device-independent arithmetic required and defined (allowed operations)? [Clarifications Q1, Edge Cases] — yes.
- [x] CHK009 Is the seam property defined precisely enough to test (shared edge heights and normals equal)? [FR-A12-102, SC-A12-102, Clarifications Q2] — yes.

## Interface, accessibility and lifecycle

- [x] CHK010 Are the camera limits quantified and consistent with "never inside the world, never below the ground"? [Clarifications Q4, US1 AC2] — yes (corrected during clarification to 10…30 m).
- [x] CHK011 Does every action have a native control with label and value? [FR-A12-121] — failed at first (zoom missing from the control list); corrected.
- [x] CHK012 Are context loss, backgrounding and Reduce Motion addressed? [Edge Cases, FR-A12-120] — yes.

## Privacy and data

- [x] CHK013 Is the saved state defined with refusal of damaged or newer payloads, and is no permission or network required? [FR-A12-122, Negative Requirements] — yes.
- [x] CHK014 Are license records and the generated document required with refusal reasons? [FR-A12-113, Clarifications Q5] — yes.

## Performance

- [x] CHK015 Are geometry and draw bounds quantified without measured performance claims? [plan Technical Context, SC-A12-105] — yes (4,225 vertices, 24,576 indices, ≤ 3 draws; no timing claims).

## Release constraints

- [x] CHK016 Is the experience kept a candidate (not available) and the reference regression deferred to X-A12 per the owner ruling? [Spec §Canonical overrides, plan Constraints] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK007 and CHK011 corrected in spec.md before marking. `/speckit-implement` reads
  these markers and does not change them.
