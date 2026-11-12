# Catalog and identity Checklist: UA-F01 — Experience catalog and stable identity

**Purpose**: Unit tests for the UA-F01 requirements: completeness, clarity, consistency, measurability, lifecycle
and failure coverage, privacy and no-advertising constraints, accessibility, the split between
simulator-verifiable and device-only requirements, and traceability to the sources
**Created**: 2026-11-12
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: reviewer-owned; `[x]` means the reviewer judged the requirement quality sufficient, not that the work
is done. `/speckit-implement` reads these markers and does not change them.

## Requirement Completeness

- [x] CHK001 Are the forms of the code, the slug and the id specified exactly? [Completeness, Spec §FR-U01-001]
- [x] CHK002 Is the form of every derived name (gate, storage namespace, evidence name, accessibility prefix) stated? [Gap, Spec §FR-U01-005]
- [x] CHK003 Is it specified which ids the golden list holds and that it only grows? [Completeness, Spec §FR-U01-004, Clarifications Q1]
- [x] CHK004 Are the exact codes of the free and the premium launch set stated? [Completeness, Spec §FR-U01-011]
- [x] CHK005 Is the rule for entries outside the launch set stated? [Completeness, Spec §FR-U01-012]
- [x] CHK006 Are all seven categories named, with the rule that separates games from creative experiences? [Completeness, Spec §FR-U01-020]
- [x] CHK007 Is every kind of refusal of the loader listed (size, schema, duplicates, missing, wrong type, unknown key, limits, numbers)? [Completeness, Spec §FR-U01-030–034]
- [x] CHK008 Are the inputs of the build tool and what each contributes specified? [Completeness, Spec §FR-U01-040, Clarifications Q2]
- [x] CHK009 Is the content of an entry without a registration specified? [Completeness, Spec §FR-U01-040]
- [x] CHK010 Are the three results of the registry check defined? [Completeness, Spec §FR-U01-050]

## Requirement Clarity

- [x] CHK011 Is "tag form" of a family defined? [Ambiguity, Spec §FR-U01-021]
- [x] CHK012 Are all limits and ranges given as numbers? [Clarity, Spec §FR-U01-030, FR-U01-033, FR-U01-034]
- [x] CHK013 Is it clear whether a summary may be empty? [Ambiguity, Spec §FR-U01-033]
- [x] CHK014 Is the format of a tile color stated? [Gap, Spec §FR-U01-033]
- [x] CHK015 Is the folding of search text defined step by step, and the result order by one rule? [Clarity, Spec §FR-U01-023, Clarifications Q4]
- [x] CHK016 Is "available" defined by one observable fact (the gate's status in the ledger)? [Clarity, Spec §FR-U01-041]
- [x] CHK017 Is it clear which files the check mode compares? [Ambiguity, Spec §FR-U01-043]

## Requirement Consistency

- [x] CHK018 Do the launch allocation, the tier rule and ADR-0009 D-02 agree (50 free, 50 premium, the same codes)? [Consistency, Spec §FR-U01-010–012]
- [x] CHK019 Do the category counts in the scenarios agree with the planning catalog (5, 4, 4, 4, 4, 4, 75)? [Consistency, Spec §US5, SC-U01-003]
- [x] CHK020 Is the strict treatment of unknown keys consistent between the clarification, the requirement and the edge case? [Consistency, Spec §Clarifications Q5, FR-U01-033, Edge Cases]
- [x] CHK021 Do the id rules agree with Auto-Creator.md section 5.2 (the id never changes, a removed id is never reused)? [Consistency, Spec §FR-U01-004]

## Acceptance Criteria Quality

- [x] CHK022 Does every acceptance item of the brief have a requirement and a measurable success criterion? [Traceability, Spec §Traceability]
- [x] CHK023 Can every success criterion be decided by a count, a comparison or an exit code? [Measurability, Spec §SC-U01-001–010]
- [x] CHK024 Is the timing criterion bounded by a number and labelled as a host figure? [Measurability, Spec §SC-U01-010, Assumptions]

## Lifecycle and Failure Coverage

- [x] CHK025 Are failure, cancellation, lifecycle interruption, memory pressure, corrupted data and newer-version data each addressed? [Coverage, Spec §Edge Cases]
- [x] CHK026 Is it specified that a failed load returns nothing partial and never crashes? [Coverage, Spec §FR-U01-035]
- [x] CHK027 Is the behavior of the build tool for unreadable or unexpected inputs specified, including that it writes nothing? [Coverage, Spec §FR-U01-044]
- [x] CHK028 Is the case of an available entry without a registration specified? [Coverage, Spec §FR-U01-042]

## Privacy, Advertising, Accessibility, Devices

- [x] CHK029 Is it stated that loading reads no clock, language setting, network or file? [Completeness, Spec §FR-U01-036]
- [x] CHK030 Is the absence of advertising, analytics, tracking and network code stated? [Completeness, Spec §Assumptions]
- [x] CHK031 Is it stated why accessibility requirements do not apply and what the feature supplies for later interfaces? [Completeness, Spec §Assumptions, FR-U01-005]
- [x] CHK032 Is the split clear: host and both simulator runtimes for the package tests, no device-only item? [Completeness, Spec §FR-U01-060, Canonical overrides]
- [x] CHK033 Are the framework obligations (documentation, API baseline, reference regression) requirements of their own? [Completeness, Spec §FR-U01-060, FR-U01-061]

## Notes

- Items are evaluated by the reviewer (the agent acting under the owner's standing delegation, as the checklist
  prompt's override asks).
- Review 2026-11-12: five items failed against the specification as it stood after `/speckit-plan` and were
  corrected in spec.md before they were marked:
  - CHK002: FR-U01-005 now states the four derived names.
  - CHK011: FR-U01-021 now defines the tag form with an example.
  - CHK013: a summary has 1 to 300 characters (FR-U01-033, Clarifications, data-model.md).
  - CHK014: FR-U01-033 now states the `#RRGGBB` form of a tile color.
  - CHK017: FR-U01-043 now names the manifest, the golden list and the test copies.
- All 33 items pass after the corrections. No item is a test of the implementation.
