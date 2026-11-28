# Requirements Quality Checklist: R02-G22-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 514 (picking, taps, previews, seed and unseed drags, scrub,
orbit, constants, panel parity, presentation state, accessibility)
**Created**: 2026-11-28
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-28, following feature 504's checklist; every item
but CHK008 passed at first reading; it was fixed in the spec the same day.

## Picking

- [x] CHK001 Is the pick priority (reverse painter's order) and each target's hit rule stated? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK002 Is the cell index computed from the cast point with a stated formula? [Measurability, Spec §Clarifications Q1]
- [x] CHK003 Is unusable input (non-finite point or size) defined as empty space? [Edge Case, Spec §Clarifications Q1]

## Taps and previews

- [x] CHK004 Are the outcomes of a tap on an empty site, a placed item, another cell, the root, a sprout and the gauge
  each defined? [Completeness, Spec §Clarifications Q2]
- [x] CHK005 Is the preview defined as the kernel's own change rule and growth, never a second implementation?
  [Consistency, Spec §FR-R02G2204-006; Clarifications Q3]
- [x] CHK006 Are the release rules that send or cancel a preview stated? [Clarity, Spec §Clarifications Q3]

## Drags and scrub

- [x] CHK007 Are the seed drag's direction rule, its tie-break and its release distance defined? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK008 Is the treatment of refused changes (a full count, an already seeded direction, a starting seed) consistent
  across the edge cases, FR-R02G2204-001 and the clarifications? [Consistency, Spec §Edge Cases; §FR-R02G2204-001]
  (fixed 2026-11-28: sent once and the refusal shown, as feature 504)
- [x] CHK009 Is the scrub formula and its availability in every stage stated? [Clarity, Spec §Clarifications Q2, Q4]

## Orbit, constants and panel

- [x] CHK010 Are the orbit rates, bounds and margin stated? [Measurability, Spec §Clarifications Q5]
- [x] CHK011 Are the gesture constants named and required equal to feature 504's? [Consistency, Spec §FR-R02G2204-010]
- [x] CHK012 Are the panel additions listed and panel parity with every certified witness required? [Completeness,
  Spec §FR-R02G2204-011]
- [x] CHK013 Is the tool choice required to use buttons rather than a segmented picker? [Clarity, Spec §Clarifications
  Q2]

## Presentation state and accessibility

- [x] CHK014 Is it stated which state is presentation only and when it resets? [Completeness, Spec §FR-R02G2204-014]
- [x] CHK015 Are the non-colour cues for ghosts, refusals and inspection defined? [Coverage, Spec §FR-R02G2204-013]
- [x] CHK016 Are the reasons given in words for gestures outside playing defined verbatim? [Clarity, Spec
  §Clarifications Q2]

## Scope

- [x] CHK017 Is touch feel recorded as a `{device}` item and are excluded items listed? [Completeness, Spec §Canonical
  overrides; Excluded scope]

## Notes

- `/speckit-implement` reads these markers and does not change them.
