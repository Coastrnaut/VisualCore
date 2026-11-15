# Mechanics Requirements Quality Checklist: Neon Arcade — Phase 02

**Purpose**: Unit tests for the requirements of A10-P02 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK004).

## Completeness

- [x] CHK001 Are the manual's Phase 02 gates (deterministic loop and authoritative rules with the complete mechanics; background/resume freezes the game; context ownership in the host) required with acceptance scenarios? [Spec §US1, §US3, FR-A10-203, 211] — yes.
- [x] CHK002 Are lanes, wave length, every pattern, the difficulty formulas and the ceiling defined with numbers? [Clarifications Q1–Q3] — yes.
- [x] CHK003 Are the new state fields and the Phase 01 migration defaults specified? [Clarifications Q4, FR-A10-210, data-model.md] — yes.
- [x] CHK004 Is the content (which hazard or orb item) and the speed of each pattern's spawns specified? [Clarifications Q2] — failed at first (patterns named only "a hazard"); Q2 now names the item per pattern and that a wall row shares one speed.

## Clarity and measurability

- [x] CHK005 Is "wall gap reachable" quantified? [Spec §FR-A10-204, SC-A10-203, Clarifications Q3, research D3] — yes (≥ 2.9 s fall vs < 1 s crossing).
- [x] CHK006 Is "difficulty rises" measurable as non-decreasing values with a ceiling? [Spec §SC-A10-202] — yes.
- [x] CHK007 Is the score rule numeric (survival points, multiplier, cap)? [Clarifications Q3, FR-A10-205] — yes.

## Architecture ownership

- [x] CHK008 Is it stated that all new rules are app-local and VisualCore is unchanged? [Spec overrides, plan] — yes.

## iOS lifecycle and recovery

- [x] CHK009 Is no-catch-up after suspension required in a later wave, with a fixture? [Spec §US3 AC1, FR-A10-221] — yes.
- [x] CHK010 Is restore of Phase 01 saved state and of damaged or newer state specified? [Spec §US3 AC2, plan Migration] — yes (migration; damaged/newer refused as in Phase 01).

## Accessibility and privacy

- [x] CHK011 Is the wave included in the spoken description and drawn without colour-only meaning? [Clarifications Q5, FR-A10-220] — yes (digits and words).
- [x] CHK012 Is the absence of new data, permissions and network stated? [Negative Requirements] — yes.

## Release constraints and licenses

- [x] CHK013 Is the pattern table licensed and listed in the license document? [FR-A10-202, 222] — yes.
- [x] CHK014 Are skill and health claims excluded? [Negative Requirements] — yes.

## Testability and performance

- [x] CHK015 Is every success criterion tied to a runnable check with test time bounds? [SC-A10-201–206, quickstart] — yes.
- [x] CHK016 Is per-step spawn work bounded and the capsule speed bound kept at the ceiling? [Clarifications Q3, plan Performance] — yes (≤ 5 spawns per step; fall ≤ 5 units/s).

## Notes

- 16 items evaluated on 2026-11-14; CHK004 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
