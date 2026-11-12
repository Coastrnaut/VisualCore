# Session Checklist: UA-F03 — Experience host and session lifecycle

**Purpose**: Unit tests for the UA-F03 requirements: completeness, clarity, consistency, measurability, lifecycle
and failure coverage, privacy and no-advertising constraints, accessibility, the split between
simulator-verifiable and device-only requirements, and traceability to the sources
**Created**: 2026-11-12
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: reviewer-owned; `[x]` means the reviewer judged the requirement quality sufficient, not that the work
is done. `/speckit-implement` reads these markers and does not change them.

## Requirement Completeness

- [x] CHK001 Are all session states and every legal change between them listed? [Gap, Spec §FR-U03-001]
- [x] CHK002 Is the order of an open stated stage by stage? [Completeness, Spec §FR-U03-003]
- [x] CHK003 Is the order of a close stated step by step? [Completeness, Spec §FR-U03-010]
- [x] CHK004 Is the content of an open request listed? [Completeness, Spec §FR-U03-003, Clarifications Q1]
- [x] CHK005 Are the moments at which a snapshot is handed out listed? [Completeness, Spec §FR-U03-042, FR-U03-070]
- [x] CHK006 Is every view of the host view named with the state it belongs to? [Completeness, Spec §FR-U03-060]
- [x] CHK007 Is every item of the session diagnostics listed? [Completeness, Spec §FR-U03-080]

## Requirement Clarity

- [x] CHK008 Is "one experience at a time" stated as something countable? [Clarity, Spec §FR-U03-002, SC-U03-001]
- [x] CHK009 Is "still over its budget" defined with a number and a default? [Ambiguity, Spec §FR-U03-051, Clarifications Q4]
- [x] CHK010 Is the preparation time limit a number with a default? [Clarity, Spec §FR-U03-022]
- [x] CHK011 Is "interruptions are honored" tied to a named phase? [Ambiguity, Spec §FR-U03-040, Assumptions]
- [x] CHK012 Is it clear which of two competing opens wins and what the other returns? [Clarity, Spec §FR-U03-004, Clarifications Q2]
- [x] CHK013 Is it clear who supplies the scene phase and who listens for memory warnings? [Clarity, Spec §FR-U03-044, Clarifications Q3]

## Requirement Consistency

- [x] CHK014 Do the close order of the requirements and the acceptance scenario of US2 agree? [Consistency, Spec §FR-U03-010, US2 scenario 1]
- [x] CHK015 Do the memory requirements, the user story and the success criterion use the same limit? [Consistency, Spec §FR-U03-051, US5, SC-U03-006]
- [x] CHK016 Is the rule for test sources in the isolation check free of contradiction? [Conflict, Spec §FR-U03-091]
- [x] CHK017 Are launcher, settings and purchases kept out of every requirement? [Consistency, Spec §FR-U03-103, Canonical overrides]

## Acceptance Criteria Quality

- [x] CHK018 Does every acceptance item of the brief have a requirement and a success criterion? [Traceability, Spec §Traceability]
- [x] CHK019 Are all success criteria stated with counts, times or sizes? [Measurability, Spec §SC-U03-001–010]
- [x] CHK020 Can the layout criterion be measured without an app target? [Measurability, Spec §SC-U03-010]

## Lifecycle and Failure Coverage

- [x] CHK021 Are failures of preparation, setup, drawing, the time limit and context recovery each covered? [Coverage, Spec §FR-U03-020, FR-U03-022, FR-U03-053]
- [x] CHK022 Is a failure while closing covered, including a leak? [Coverage, Spec §FR-U03-011, FR-U03-023]
- [x] CHK023 Is it specified what happens to a snapshot the experience refuses at open, and to one it cannot produce? [Gap, Spec §FR-U03-005, FR-U03-070]
- [x] CHK024 Are opens during preparing, failed, message and closing covered? [Coverage, Spec §FR-U03-004, Edge Cases]
- [x] CHK025 Is the case of a preparation that ends in the background covered? [Coverage, Spec §FR-U03-043]
- [x] CHK026 Are closing when idle and closing twice covered? [Edge Case, Spec §FR-U03-013]
- [x] CHK027 Is the case of a missing surface covered? [Edge Case, Spec §Edge Cases]

## Privacy, Advertising, Accessibility, Devices

- [x] CHK028 Is it a requirement that the session neither writes files nor uses the network? [Completeness, Spec §FR-U03-071, FR-U03-103]
- [x] CHK029 Are labels, identifiers, text size and color-independence of the host view required? [Completeness, Spec §FR-U03-061, FR-U03-062]
- [x] CHK030 Is the device-only item named and kept out of simulator claims? [Completeness, Spec §FR-U03-104]
- [x] CHK031 Is the behavior of the isolation check for a folder without sources specified? [Gap, Spec §FR-U03-090]

## Traceability and Dependencies

- [x] CHK032 Does every functional requirement appear in the traceability table? [Traceability, Spec §Traceability]
- [x] CHK033 Is every unique requirement of R02-F04 and R02-F25 listed with a decision and a reason? [Traceability, Spec §Absorbed source requirements]
- [x] CHK034 Are the framework obligations requirements of their own? [Completeness, Spec §FR-U03-101, FR-U03-102]

## Notes

- Items are evaluated by the reviewer (the agent acting under the owner's standing delegation, as the checklist
  prompt's override asks).
- Review 2026-11-12: five items failed against the specification as it stood after `/speckit-plan` and were
  corrected in spec.md before they were marked:
  - CHK001: FR-U03-001 now lists the 17 legal changes of state.
  - CHK016: FR-U03-091 now states one rule for test sources instead of an exception list.
  - CHK020: SC-U03-010 now states what a package test can measure and names UA-F04 for taps.
  - CHK023: FR-U03-070 now covers a snapshot that cannot be produced.
  - CHK031: FR-U03-090 now states exit code 0 for "no sources" and the option that makes it a failure.
- All 34 items pass after the corrections. No item is a test of the implementation.
