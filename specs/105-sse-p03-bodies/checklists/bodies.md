# Bodies Requirements Quality Checklist: Solar System Explorer — Phase 03

**Purpose**: Unit tests for the requirements of A14-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are both Phase 03 gates (recognisable bodies from a focusable camera; focus and scale fixtures) required with measurable outcomes? [Spec §Canonical overrides, SC-A14-301–304] — yes.
- [x] CHK002 Is every body's surface style and palette stated, including the Sun's emission and Earth's caps? [FR-A14-301, Clarifications Q1] — yes.
- [x] CHK003 Are Saturn's ring radii, division, source, epoch, units and license stated? [FR-A14-302, Clarifications Q2] — yes.
- [x] CHK004 Is the move of on-canvas labels to A14-P04 stated with what names the bodies meanwhile? [Canonical overrides, Negative Requirements] — yes.

## Clarity and consistency

- [x] CHK005 Are both scale mappings quantified (4·√r with display radii; 2 units per AU for positions and radii) with their labels? [FR-A14-310, Clarifications Q3] — yes.
- [x] CHK006 Is the starfield's placement consistent with the near and far planes of both modes? [FR-A14-303, Clarifications Q5] — failed (a fixed far distance would fall beyond the true-relative far plane, camera distance + 70, when zoomed in); the spec, data model and contract now centre the 400 stars on the eye at 0.9 × the active far plane.
- [x] CHK007 Is the marker rule quantified (below 2 px drawn radius; 6 px marker) and kept apart from the body's drawn size? [FR-A14-311, Clarifications Q3] — yes.
- [x] CHK008 Are the flight's length, easing, clearance and restart rule defined? [FR-A14-320, 321, Clarifications Q4] — yes.

## Architecture ownership

- [x] CHK009 Is the 3D noise's app-local placement justified and VisualCore left unchanged? [Clarifications Q1, Plan Constitution Check II-a] — yes.
- [x] CHK010 Is the flight kept out of the core state so digests do not depend on frame timing? [Clarifications Q4, Plan Lifecycle] — yes.

## iOS lifecycle and edge cases

- [x] CHK011 Are creation, rebuild after context recreation and release of every renderer specified, with the shared-program rule? [Plan Lifecycle, Edge Cases] — yes.
- [x] CHK012 Are back-face culling and the two-sided ring addressed? [Clarifications Q2] — yes.
- [x] CHK013 Are Reduce Motion behaviour and the schema 2 → 3 migration defined? [FR-A14-320, 330] — yes.

## Accessibility and privacy

- [x] CHK014 Are the active scale mode's display and announcement and the "not to scale" wording required? [FR-A14-312, contracts/bodies.md] — yes.
- [x] CHK015 Are no network, no textures and no imported models stated? [Negative Requirements] — yes.

## Testability and performance

- [x] CHK016 Can every success criterion be checked without a device, with mesh sizes bounded and no frame-rate claim? [SC-A14-301–305, Plan Technical Context, quickstart] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
