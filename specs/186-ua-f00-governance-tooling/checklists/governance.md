# Governance tooling Checklist: UA-F00 — feature numbering, validators and ledger operation

**Purpose**: Unit tests for the UA-F00 requirements: completeness, clarity, consistency, measurability, lifecycle
and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable
and device-only requirements, and traceability to the sources
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: reviewer-owned; `[x]` means the reviewer judged the requirement quality sufficient, not that the work
is done. `/speckit-implement` reads these markers and does not change them.

## Requirement Completeness

- [x] CHK001 Are all seven directory forms of the numbering map listed with their namespaces? [Completeness, Spec §FR-U00-001]
- [x] CHK002 Are the directories outside the map named concretely enough to build fixtures from them? [Completeness, Spec §FR-U00-002, US1 scenario 6]
- [x] CHK003 Is every refusal of the tick tool listed, including a missing task list and multi-line evidence? [Completeness, Spec §FR-U00-011]
- [x] CHK004 Is the outcome of a push that fails for a reason other than a scan finding specified? [Gap, Spec §FR-U00-014, Edge Cases]
- [x] CHK005 Are all kinds of value the scan must find, and all classes of forbidden path, enumerated? [Completeness, Spec §FR-U00-020, FR-U00-022]
- [x] CHK006 Are the six ledger refusals of the brief each a requirement of their own? [Completeness, Spec §FR-U00-030–035]
- [x] CHK007 Is it specified which features count as pending launch features and which are skipped? [Completeness, Spec §FR-U00-040, FR-U00-041, Assumptions]
- [x] CHK008 Are the four validators and the scan each named as a CI requirement, for pushes and for pull requests? [Completeness, Spec §FR-U00-050, FR-U00-051]
- [x] CHK009 Is every unique requirement of the absorbed feature R02-F01 listed as adopted, adapted or superseded with a reason? [Completeness, Spec §Absorbed source requirements]

## Requirement Clarity

- [x] CHK010 Is the exact shape of an id stated for each directory form, so that "in its namespace" has one meaning? [Clarity, Spec §FR-U00-003, Clarifications Q4]
- [x] CHK011 Is the date written by a tick defined (which day, which clock)? [Ambiguity, Spec §FR-U00-010]
- [x] CHK012 Is "the same verdict on the development Mac and in CI" defined by a mechanism that can be checked? [Clarity, Spec §FR-U00-025, Clarifications Q1]
- [x] CHK013 Is "exactly the commits of the push or the pull request" defined by its two end points? [Clarity, Spec §FR-U00-051, Clarifications Q2]
- [x] CHK014 Is "a reviewed list of readers" defined: where the list lives and how a reader is added? [Ambiguity, Spec §FR-U00-039]
- [x] CHK015 Is "the only way a commit is pushed" stated as what it can be (procedure plus detection) rather than as a guarantee that tracked files cannot give? [Clarity, Spec §FR-U00-015, Clarifications Q3]

## Requirement Consistency

- [x] CHK016 Do the stricter id rules agree with the requirement that the 35 sealed dossiers stay unchanged? [Consistency, Spec §FR-U00-004, FR-U00-007, Clarifications Q4]
- [x] CHK017 Do the user stories, the requirements and the success criteria use the same counts (seven forms, five new namespaces, six ledger refusals, eight stages)? [Consistency, Spec §US1–US6, SC-U00-001–007]
- [x] CHK018 Is the rule "no readable identifier is tracked" consistent with accepting the development Mac's simulator identifiers? [Consistency, Spec §FR-U00-025, FR-U00-026]
- [x] CHK019 Do the requirements agree with ADR-0009 D-11 (numbering), D-12 (two ledgers, legacy ledger untouched) and D-13 (work on `main`, push after the scan)? [Consistency, Spec §FR-U00-001, FR-U00-035, FR-U00-014, FR-U00-060]

## Acceptance Criteria Quality

- [x] CHK020 Does every acceptance item of the brief have at least one requirement and one measurable success criterion? [Traceability, Spec §Traceability]
- [x] CHK021 Can each success criterion be decided by a count, a comparison or an exit code? [Measurability, Spec §SC-U00-001–010]
- [x] CHK022 Is the prompt coverage criterion measurable although the number of pending features falls as gates pass? [Measurability, Spec §SC-U00-007]
- [x] CHK023 Is the timing criterion labelled as a host measurement and bounded by a number? [Measurability, Spec §SC-U00-009, Assumptions]

## Lifecycle and Failure Coverage

- [x] CHK024 Are requirements defined for a command that fails or times out as evidence? [Coverage, Spec §Edge Cases, FR-U00-032]
- [x] CHK025 Are requirements defined for an interrupted tick and an interrupted ledger command? [Coverage, Spec §Edge Cases, FR-U00-012]
- [x] CHK026 Is the case "session ends between seal and record" specified? [Coverage, Spec §Edge Cases]
- [x] CHK027 Are damaged, missing and newer-version files covered for the ledger, the attestations, the evidence and the hash list? [Coverage, Spec §FR-U00-036, FR-U00-025, Edge Cases]
- [x] CHK028 Is the failure of the CI scan specified for a range it cannot determine or read? [Coverage, Spec §FR-U00-051, US6 scenario 4]
- [x] CHK029 Is it specified that the self-tests never change the real ledger, and how that is observed? [Coverage, Spec §FR-U00-038, SC-U00-006]

## Privacy, Advertising, Accessibility

- [x] CHK030 Are the privacy requirements complete: what must not be pushed, what must never be tracked, and that no readable identifier is stored? [Completeness, Spec §FR-U00-020–025]
- [x] CHK031 Does the specification state that the tools use no network (except the push), no model and no account? [Completeness, Spec §FR-U00-061, FR-U00-052]
- [x] CHK032 Is the no-advertising, no-analytics and no-tracking constraint stated for this feature, even though it adds no app code? [Gap, Spec §FR-U00-061]
- [x] CHK033 Is it stated why accessibility requirements do not apply (no user interface)? [Gap, Spec §Assumptions]

## Simulator and Device Split, Dependencies

- [x] CHK034 Is it stated that the feature has no device-only and no owner-only item, and that no simulator test applies? [Completeness, Spec §Canonical overrides, Plan §Tests of each layer]
- [x] CHK035 Are the external dependencies of the evidence (GitHub Actions, the `gh` command) documented as assumptions? [Dependency, Spec §Assumptions]
- [x] CHK036 Is the out-of-scope boundary (app and framework source, legacy ledger and its tool) a requirement with a measurable check? [Completeness, Spec §FR-U00-060, SC-U00-010]

## Notes

- Items are evaluated by the reviewer (the agent acting under the owner's standing delegation, as the checklist
  prompt's override asks).
- Review 2026-11-11: six items failed against the specification as it stood after `/speckit-plan` and were
  corrected in spec.md before they were marked:
  - CHK004: FR-U00-014 and Edge Cases now say what happens when the push itself fails (the commit stays local, the
    tool fails and names the command that pushes later).
  - CHK011: FR-U00-010 now says the date is the local date of the machine that ticks.
  - CHK014: FR-U00-039 now says the list of readers is part of the self-tests and that adding a reader is a change
    to that list.
  - CHK032: FR-U00-061 now states that the tools contain no advertising, analytics or tracking code.
  - CHK033: Assumptions now state that accessibility requirements do not apply and why.
  - CHK035: Assumptions now name GitHub Actions and the `gh` command as dependencies of FR-U00-053.
- All 36 items pass after the corrections. No item is a test of the implementation.
