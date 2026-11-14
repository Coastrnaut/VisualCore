# Habitat Requirements Quality Checklist: Digital Aquarium — Phase 01

**Purpose**: Unit tests for the requirements of A09-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK010).

## Completeness

- [x] CHK001 Are the manual's two Phase 01 gates (one aquarium with two species and plants; fish stay in the swim bounds) both required with acceptance scenarios? [Spec §US1, §US2, FR-A09-102, 110] — yes.
- [x] CHK002 Are all fields of the habitat document and catalog items defined with ranges? [Spec §FR-A09-101, 102; data-model.md] — yes.
- [x] CHK003 Are the catalog refusal reasons enumerated? [Clarifications Q3, FR-A09-103] — yes (six named reasons).

## Clarity and measurability

- [x] CHK004 Are the swim bounds and units quantified? [Clarifications Q2] — yes (16 × 9 tank, x 0.5…15.5, y 1.5…8.5).
- [x] CHK005 Is "fish stay inside" measurable over a stated run length and seed count? [Spec §SC-A09-102] — yes (10,000 steps, ≥ 20 seeds).
- [x] CHK006 Are fish and plant counts bounded with numbers? [Clarifications Q5, Edge Cases] — yes (≤ 24 fish, ≤ 12 plants; starters 6–10 and 4–6).

## Architecture ownership

- [x] CHK007 Is it stated which pieces stay app-local (habitat, catalog, wander) and which go to VisualCore later (steering in A09-P02)? [Spec overrides, Assumptions] — yes.

## iOS lifecycle and recovery

- [x] CHK008 Is "no fast-forward after suspension" specified with the mechanism (simulation advances only by host steps)? [Spec §US4 AC2, FR-A09-111, plan Lifecycle] — yes.
- [x] CHK009 Is the behaviour for a damaged or newer saved state specified? [Spec §US4 AC3] — yes (refused; starter habitat opens).

## Accessibility and privacy

- [x] CHK010 Are accessibility requirements for the controls and Reduce Motion stated as functional requirements? [Spec §FR-A09-123] — failed at first (only an edge-case note without a measure); FR-A09-123 now requires labels and values and halves the drawn motion (sway, tail swing) under Reduce Motion; the state stays independent of the preference.
- [x] CHK011 Is the absence of permissions and network stated? [Spec §Negative Requirements] — yes.

## Release constraints and licenses

- [x] CHK012 Is the license rule measurable (allowed list, author required, audit document checked)? [Clarifications Q3, FR-A09-104, SC-A09-103] — yes.
- [x] CHK013 Are realism, animal-care and wellbeing claims excluded, and species names kept descriptive? [Negative Requirements, Clarifications Q4] — yes.

## Testability and performance

- [x] CHK014 Is every success criterion tied to a runnable check with test time bounds? [SC-A09-101–105, quickstart] — yes.
- [x] CHK015 Is the per-frame drawing load bounded without performance claims? [Clarifications Q5] — yes (≤ 36 shapes plus background; no fps claim).

## Notes

- 15 items evaluated on 2026-11-14; CHK010 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
