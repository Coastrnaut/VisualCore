# QA Requirements Quality Checklist: Tiny Worlds — Phase 05

**Purpose**: Unit tests for the requirements of A12-P05 (tier table, pressure policy, stale-object fixture, saved-world
round trips, truthful claims, device-campaign scope)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); two items failed and were corrected
before this record (CHK004, CHK008).

## Completeness

- [x] CHK001 Are both Phase 05 gates (saved worlds under stress; no stale graphics objects across load/unload) required with measurable outcomes? [Spec §Canonical overrides, SC-A12-503, 504] — yes.
- [x] CHK002 Does the tier table name every quantity per tier (terrain cells per preset, draw count, thumbnail size)? [Clarifications Q2, Contract] — yes.
- [x] CHK003 Are all three pressure sources and their origins defined (host level, Low Power Mode, memory warnings)? [Clarifications Q1] — yes.
- [x] CHK004 Do the key entities match the clarified tier table? [Spec §Key Entities] — failed ("prop draw cap, draw cap" contradicted Q2); corrected to terrain cells, draws 2 + props, 160 × 120.
- [x] CHK005 Are the stale-object cycle's steps, count and pass condition defined? [Clarifications Q4, SC-A12-503] — yes (20 cycles, five steps, equal live counts, 0 on close, 0 leaks).
- [x] CHK006 Is the device-campaign scope listed (TW-D1…D5) and tagged {device}? [Clarifications Q5, FR-A12-507] — yes.

## Clarity

- [x] CHK007 Is the tier rule an explicit formula with stated floors and the memory hold? [Clarifications Q3, Contract] — yes.
- [x] CHK008 Is the thermal edge case consistent with the host governor's authority? [Spec §Edge Cases] — failed ("hold time" of the experience); corrected to the host governor's once-per-second decision.
- [x] CHK009 Is the clock of the memory hold defined so tests are deterministic? [Research D2] — yes (presenter frame clock).
- [x] CHK010 Are the refused claim words listed exactly, with matching rules and the exemption? [Clarifications Q5, Contract] — yes.

## Consistency

- [x] CHK011 Do the declared quality levels, the drawn levels and the registration agree (three, level-0…2)? [FR-A12-505, Contract] — yes.
- [x] CHK012 Is "the digest never changes" stated the same in spec, research and contract? [FR-A12-502, D2, Contract] — yes.
- [x] CHK013 Do lower tiers never raise a count in both the FR and the SC? [FR-A12-501, SC-A12-501] — yes.

## Acceptance criteria and coverage

- [x] CHK014 Can every SC be checked by a test or script without a device? [SC-A12-501…506] — yes.
- [x] CHK015 Are repeated warnings, Low Power at launch, context loss during a change and lowest-tier thumbnails covered? [Spec §Edge Cases] — yes.
- [x] CHK016 Are saved-world round trips required across both tiers and packs? [FR-A12-504, SC-A12-504] — yes.

## Non-functional, dependencies and boundaries

- [x] CHK017 Are performance claims excluded and device measures deferred, with no wall-clock assertion? [Negative Requirements, Spec §Canonical overrides] — yes.
- [x] CHK018 Are only verified host APIs assumed (setQualityTier, shedCaches, ResourceRegistry stats, recreateContext)? [Plan §Technical Context] — yes.
- [x] CHK019 Is the graphics-context ownership boundary stated (host only)? [Spec §Canonical overrides] — yes.
- [x] CHK020 Is no schema change and no new content required (rollback by revert)? [Plan, Negative Requirements] — yes.
