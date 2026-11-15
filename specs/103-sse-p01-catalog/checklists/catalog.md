# Catalog Requirements Quality Checklist: Solar System Explorer — Phase 01

**Purpose**: Unit tests for the requirements of A14-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are all three Phase 01 gates (Sun and planets with fact cards, fixture of periods and radii, host owns the context) required with measurable outcomes? [Spec §Canonical overrides, SC-A14-101, SC-A14-104] — yes.
- [x] CHK002 Are the stored quantities, their units and their values enumerated? [FR-A14-101, Clarifications Q2] — yes.
- [x] CHK003 Is the source, epoch and license of every value stated, with the allowed licenses? [FR-A14-110, Clarifications Q1] — yes.
- [x] CHK004 Are the experience's state, actions, refusals and fixtures specified? [FR-A14-121, 122, Clarifications Q5] — yes.

## Clarity and consistency

- [x] CHK005 Are the conversion constants exact and named (1 AU = 149,597,870.7 km; 365.25 days per Julian year)? [FR-A14-102] — yes.
- [x] CHK006 Are the catalog document's validation limits quantified so "out of range" is testable? [FR-A14-104, data model] — failed (no ranges were given); the data model now states the counts and value ranges.
- [x] CHK007 Is the fixture tolerance quantified (1 % relative) and the fixture independent of the catalog? [FR-A14-103, Clarifications Q3] — yes.
- [x] CHK008 Is the drawn layout defined (display radii formula, spacing, not-to-scale label)? [FR-A14-120, Clarifications Q4] — yes.

## Architecture ownership

- [x] CHK009 Is the core free of rendering and UI dependencies, and the adapter named so it does not shadow its module? [Plan Dependency direction] — yes.
- [x] CHK010 Is reuse of the UV sphere, the lit mesh renderer and the orbit camera required with no upstream change? [Plan Technical Context, Constitution II] — yes.

## iOS lifecycle and edge cases

- [x] CHK011 Are GPU objects' creation, rebuild after context recreation and release specified? [Plan Lifecycle] — yes.
- [x] CHK012 Are the Sun's missing orbit values, retrograde tilts, rounding and end-of-list refusals addressed? [Spec §Edge Cases] — yes.

## Accessibility and privacy

- [x] CHK013 Are native controls with labels and values and the spoken not-to-scale notice required? [FR-A14-121, Clarifications Q4] — yes.
- [x] CHK014 Are no network, no textures and no unlicensed data stated? [Negative Requirements, constitution A14] — yes.

## Testability and performance

- [x] CHK015 Can every success criterion be checked without a device? [SC-A14-101–105, quickstart] — yes.
- [x] CHK016 Are mesh sizes bounded and no performance figures claimed? [Plan Technical Context] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
