# Requirements Quality Checklist: UA-F10 — Build, project and CI consolidation

**Purpose**: Unit tests for the requirements of UA-F10 (completeness, clarity, consistency, measurability,
failure coverage, boundaries, accessibility, simulator/device split, traceability)
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement text adequate, not that the work is done. Evaluated
2026-11-13 by the lead under the owner's standing delegation; failed items were corrected in the specification
first, and the correction is named.

## Requirement Completeness

- [x] CHK001 Are requirements defined for both build configurations CI must compile, including the test bundles? [Spec §FR-U10-001]
- [x] CHK002 Is it specified what CI links in place of the locally built renderer frameworks, and how a leak into a real app is detected? [Spec §FR-U10-002, Clarifications]
- [x] CHK003 Are all application targets and their shipping status required to be declared in one checkable place? [Spec §FR-U10-010]
- [x] CHK004 Is the mapping from experience round to package fully specified for all four packages? [Spec §FR-U10-021]
- [x] CHK005 Are all three forbidden dependency kinds (cross-experience import, cross-experience target dependency, ProjectM import) stated? [Spec §FR-U10-030]
- [x] CHK006 Is it specified how verification steps follow new registrations without manual edits? [Spec §FR-U10-040] — failed first; corrected: steps are derived from `Catalog/registrations.json`.
- [x] CHK007 Are the three recorded measurements and the fields of a record specified? [Spec §FR-U10-050, Key Entities]

## Requirement Clarity

- [x] CHK008 Is "within ten minutes" expressed as a concrete limit per step? [Spec §SC-U10-005]
- [x] CHK009 Is "incremental build" defined by the kind of change that precedes it? [Spec §FR-U10-050]
- [x] CHK010 Is "implemented experience" defined unambiguously (registered in the registrations file)? [Plan research R3, Spec §Assumptions]
- [x] CHK011 Is the condition that ends a non-shipping target's exemption stated? [Spec §FR-U10-011, Clarifications]

## Requirement Consistency

- [x] CHK012 Are the CI requirements consistent with the rule that nobody waits on CI? [Spec §Overrides, §Edge Cases]
- [x] CHK013 Is the deferral of accessibility audits consistent between the overrides, story 5 and FR-U10-042? [Spec §FR-U10-042]
- [x] CHK014 Are the one-app requirements consistent with keeping the Particle Universe target until X-A04? [Spec §FR-U10-010, §Assumptions]

## Acceptance Criteria Quality

- [x] CHK015 Does every success criterion name a count or a time that can be checked? [Spec §SC-U10-001…007]
- [x] CHK016 Do the criteria for the validators require planted defects, not only a passing tree? [Spec §SC-U10-002…004]

## Scenario and Edge-Case Coverage

- [x] CHK017 Are cancelled, skipped and queued CI runs addressed? [Spec §Edge Cases] — failed first for queued runs; corrected: a queued run is not evidence and nobody waits for it.
- [x] CHK018 Are missing renderer frameworks, a missing simulator runtime and a busy simulator addressed? [Spec §Edge Cases]
- [x] CHK019 Are damaged or newer-schema data files addressed for every tracked file the feature reads or writes? [Spec §Story 3, §Story 6, §FR-U10-050]
- [x] CHK020 Is the absence of an experience package for a round without implemented experiences addressed? [Spec §Story 3 scenario 2]

## Non-Functional, Boundaries and Device Split

- [x] CHK021 Are the no-advertising, no-network and one-renderer boundaries restated for this feature? [Spec §FR-U10-070]
- [x] CHK022 Is it stated that nothing in this feature needs a device or an owner action? [Spec §Overrides]
- [x] CHK023 Is CI signing explicitly excluded, and the public-repository constraint on binaries stated? [Spec §FR-U10-002, §FR-U10-004]

## Traceability

- [x] CHK024 Is every absorbed source requirement listed with its disposition and reason? [Spec §FR-U10-060, research §3]
- [x] CHK025 Does every acceptance item of the brief map to at least one requirement and one success criterion? [Spec §FR-U10-001…051, §SC-U10-001…006]

## Notes

- `/speckit-implement` reads these markers and does not change them.
