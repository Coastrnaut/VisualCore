# Core Requirements Checklist: Visual Programming Lab — Phase 01 Graph schema and type-checking fixtures

**Purpose**: Unit tests for the requirements of A23-P01 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) found the requirement-quality criterion
satisfied; it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all seven node kinds' ports, value types, requiredness and parameter ranges and defaults specified? [Completeness, Spec §Clarifications Q1, FR-A23-103]
- [x] CHK002 Are the graph's limits (nodes, connections, identities, positions) stated as numbers? [Completeness, Spec §Clarifications Q2, FR-A23-101]
- [x] CHK003 Is every refusal code of the file defined with the conditions that produce it? [Completeness, Spec §Clarifications Q3, FR-A23-102]
- [x] CHK004 Is every checker refusal named, with the node, port or path it carries? [Completeness, Spec §FR-A23-104–106, data-model GraphIssue]

## Requirement Clarity

- [x] CHK005 Is the cycle path defined deterministically (which loop, which starting connection, which direction)? [Clarity, Spec §Clarifications Q4, US3]
- [x] CHK006 Is the node order's tie-break specified so the same graph always gives the same order? [Clarity, Spec §Clarifications Q4, SC-A23-103]
- [x] CHK007 Is "matching ports" defined without implicit conversions, including time versus scalar? [Clarity, Spec §Clarifications Q1, US2]

## Requirement Consistency

- [x] CHK008 Do the edge cases agree with the checker stages (a loop is never reported as another error; limits are checked first)? [Consistency, Spec §Edge Cases, Clarifications Q4]
- [x] CHK009 Do the file's refusals and the checker's refusals divide the work without overlap (schema-level on reading, meaning-level in the checker)? [Consistency, Spec §Clarifications Q2–Q4]

## Acceptance Criteria Quality

- [x] CHK010 Are the success criteria countable (16 type pairs, the named cycle fixtures, 10 identical runs, unchanged host counts)? [Measurability, Spec §SC-A23-101–106]

## Architecture Ownership and Lifecycle

- [x] CHK011 Is it stated that the core owns no graphics context and that the host's counts prove no graphics work during checking? [Coverage, Spec §FR-A23-107, US5, Clarifications Q5]
- [x] CHK012 Are the reused VisualCore declarations named and checked in code, with no VisualCore change? [Dependency, Spec §Clarifications facts, Negative Requirements]

## Privacy, Performance and Release

- [x] CHK013 Is the absence of network, permission and personal data stated? [Coverage, Spec §Negative Requirements]
- [x] CHK014 Is the checker's cost bounded by the limits, with no wall-clock assertion? [Non-Functional, plan Technical Context, SC-A23-106]
- [x] CHK015 Is it stated that nothing is registered or shown to people in this phase, so no store, privacy or release text changes? [Coverage, Spec §Negative Requirements]
- [x] CHK016 Is the schema migration path for a later version stated (the migration chain as the hook)? [Coverage, Spec §Clarifications Q3, plan Migration]

## Notes

- One correction during evaluation: the edge case on impossible connections now includes a connection into an output
  (matching the checker's `wrong-direction`).
