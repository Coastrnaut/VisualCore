# Experience contract Checklist: UA-F02 — ExperienceKit: the experience contract

**Purpose**: Unit tests for the UA-F02 requirements: completeness, clarity, consistency, measurability, lifecycle
and failure coverage, privacy and no-advertising constraints, accessibility, the split between
simulator-verifiable and device-only requirements, and traceability to the sources
**Created**: 2026-11-12
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: reviewer-owned; `[x]` means the reviewer judged the requirement quality sufficient, not that the work
is done. `/speckit-implement` reads these markers and does not change them.

## Requirement Completeness

- [x] CHK001 Are all eight lifecycle states and the starting state named? [Completeness, Spec §FR-U02-001]
- [x] CHK002 Is every legal transition listed, so that every other pair is known to be illegal? [Completeness, Spec §FR-U02-002, FR-U02-003]
- [x] CHK003 Is it specified for every operation of the contract in which states it is legal? [Completeness, Spec §FR-U02-006]
- [x] CHK004 Are the inputs that preparation may and may not use specified? [Completeness, Spec §FR-U02-010]
- [x] CHK005 Is it specified what a digest must not depend on? [Completeness, Spec §FR-U02-013]
- [x] CHK006 Are the fields of a snapshot envelope listed, including what it must never hold? [Completeness, Spec §FR-U02-040]
- [x] CHK007 Is every reason for refusing a restore listed and counted? [Completeness, Spec §FR-U02-042, FR-U02-043]
- [x] CHK008 Are the parts of an action and the declaration of a control specified? [Completeness, Spec §FR-U02-030, FR-U02-031]
- [x] CHK009 Is every item of the diagnostics value listed, including the counters the contract keeps? [Gap, Spec §FR-U02-060]
- [x] CHK010 Are all checks of the conformance helper listed? [Completeness, Spec §FR-U02-070]
- [x] CHK011 Is it specified which part of an experience is pure and which runs on the main actor? [Completeness, Spec §FR-U02-080, Clarifications Q1]

## Requirement Clarity

- [x] CHK012 Is the size and form of the digest stated exactly? [Clarity, Spec §FR-U02-013, Clarifications Q2]
- [x] CHK013 Is the bound of the lifecycle history a number? [Ambiguity, Spec §FR-U02-004]
- [x] CHK014 Are the allowed step lengths, the default and the treatment of a length outside the range stated? [Gap, Spec §FR-U02-020]
- [x] CHK015 Are the limits of steps per frame, values per action and snapshot size numbers? [Clarity, Spec §FR-U02-022, FR-U02-030, FR-U02-043]
- [x] CHK016 Is "checks for cancellation at bounded intervals" made measurable? [Ambiguity, Spec §FR-U02-016, SC-U02-010]
- [x] CHK017 Is it clear which seed a reset uses after a restore? [Clarity, Spec §FR-U02-045]
- [x] CHK018 Is the form of the payload and of 64-bit values in the encoded snapshot stated? [Clarity, Spec §FR-U02-040, FR-U02-046, Clarifications Q3]
- [x] CHK019 Is it clear what "absent" means for a diagnostics item that does not exist yet? [Clarity, Spec §FR-U02-060, US6 scenario 1]

## Requirement Consistency

- [x] CHK020 Do the number of conformance checks, the number of broken variants and the success criterion agree? [Consistency, Spec §FR-U02-070, FR-U02-073, US7, SC-U02-008]
- [x] CHK021 Do the number of refusal reasons in the requirements and in the success criterion agree? [Conflict, Spec §FR-U02-043, SC-U02-003]
- [x] CHK022 Do the transition list, the operation list and the user stories agree on cancellation ending in inactive? [Consistency, Spec §FR-U02-002, FR-U02-011, US2 scenario 7]
- [x] CHK023 Is the two-part shape of the clarifications reflected in the requirements and the key entities? [Consistency, Spec §Clarifications Q1, FR-U02-080, Key Entities]
- [x] CHK024 Are the session host's duties kept out of the requirements, as the out-of-scope list says? [Consistency, Spec §FR-U02-084, Assumptions]

## Acceptance Criteria Quality

- [x] CHK025 Does every acceptance item of the brief have at least one requirement and one success criterion? [Traceability, Spec §Traceability]
- [x] CHK026 Are all success criteria stated with counts, percentages or times? [Measurability, Spec §SC-U02-001–010]
- [x] CHK027 Is it stated where the time-based criteria are measured? [Clarity, Spec §SC-U02-008, SC-U02-010, Assumptions]

## Lifecycle and Failure Coverage

- [x] CHK028 Are failure during preparation, during setup and during drawing each covered? [Coverage, Spec §FR-U02-012, Edge Cases]
- [x] CHK029 Is it specified what happens to a late preparation result? [Coverage, Spec §FR-U02-016]
- [x] CHK030 Is it specified what happens when GPU objects remain at the end of deactivation? [Gap, Spec §FR-U02-052]
- [x] CHK031 Is the answer to a quality tier that was not declared specified? [Gap, Spec §FR-U02-054]
- [x] CHK032 Is the answer to an action whose step index is not the current one specified? [Gap, Spec §FR-U02-032]
- [x] CHK033 Are suspension, memory pressure and context loss each covered by a requirement? [Coverage, Spec §FR-U02-024, FR-U02-055, FR-U02-052]
- [x] CHK034 Is it specified that a refused restore and a rejected action change nothing? [Coverage, Spec §FR-U02-044, FR-U02-033]
- [x] CHK035 Are repeated calls (deactivate twice, prepare while preparing) covered? [Edge Case, Spec §Edge Cases, FR-U02-006]

## Privacy, Advertising, Accessibility, Devices

- [x] CHK036 Is the absence of advertising, analytics, tracking, purchase and network code a requirement? [Completeness, Spec §FR-U02-084]
- [x] CHK037 Is it stated what the contract must offer for accessibility and why screen audits belong to later features? [Completeness, Spec §FR-U02-056, Assumptions]
- [x] CHK038 Is the split clear: host for the pure parts, both simulator runtimes for the parts that need a render host, and no device-only item? [Completeness, Spec §FR-U02-072, FR-U02-082, Canonical overrides]
- [x] CHK039 Is it measurable that the sample is not part of a shipped product? [Measurability, Spec §FR-U02-072]
- [x] CHK040 Is the proof of absence of the automation hooks specified? [Measurability, Spec §FR-U02-062, SC-U02-007]

## Traceability and Dependencies

- [x] CHK041 Does every functional requirement appear in the traceability table? [Traceability, Spec §Traceability]
- [x] CHK042 Is every unique requirement of the absorbed feature R02-F23 listed with a decision and a reason? [Traceability, Spec §Absorbed source requirements]
- [x] CHK043 Are the existing surfaces that must stay unchanged named? [Dependency, Spec §FR-U02-081]
- [x] CHK044 Are the framework obligations (documentation, API baseline, package tests, reference regression) requirements of their own? [Completeness, Spec §FR-U02-082, FR-U02-083]

## Notes

- Items are evaluated by the reviewer (the agent acting under the owner's standing delegation, as the checklist
  prompt's override asks).
- Review 2026-11-12: ten items failed against the specification as it stood after `/speckit-plan` and were
  corrected in spec.md before they were marked:
  - CHK009: FR-U02-060 now lists the counters (rejected transitions, refused operations, accepted and rejected
    actions, dropped time, invalid frames).
  - CHK013: FR-U02-004 now states the history bound (64 unless the caller sets another limit).
  - CHK014: FR-U02-020 now states the default step length and the treatment of a length outside the range.
  - CHK016: FR-U02-016 now ties the cancellation checks to the one-second criterion.
  - CHK021: FR-U02-043 and SC-U02-003 now both count eight typed refusal reasons.
  - CHK030: FR-U02-052 now makes a remaining GPU object a typed failure and the lifecycle failed.
  - CHK031: FR-U02-054 now refuses a tier that was not declared.
  - CHK032: FR-U02-032 now lists the step index that is not the current one.
  - CHK039: FR-U02-072 now names the dependency check that proves it.
  - CHK041: the traceability table now includes FR-U02-063 and FR-U02-071; a script confirmed that all 57
    functional requirements appear in it.
- FR-U02-025 was sharpened in the same pass (the step index is a 64-bit count), which settles the overflow edge
  case.
- All 44 items pass after the corrections. No item is a test of the implementation.
