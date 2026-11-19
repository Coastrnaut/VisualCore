# Preview Requirements Checklist: Visual Programming Lab — Phase 03 Bounded graph compiler and preview

**Purpose**: Unit tests for the requirements of A23-P03 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) found the requirement-quality criterion
satisfied; it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Is every node kind's compiled form (passes or values) specified, including unconnected inputs? [Completeness, Spec §Clarifications Q1, FR-A23-301]
- [x] CHK002 Is each operator's formula stated so a reference can be computed? [Completeness, Spec §Clarifications Q4, FR-A23-302]
- [x] CHK003 Are the slot size, format, limit and refusal sentence stated as numbers? [Completeness, Spec §Clarifications Q2, FR-A23-304]
- [x] CHK004 Is every preview state named with its message and drawing behaviour? [Completeness, Spec §Clarifications Q5, FR-A23-303]

## Requirement Clarity

- [x] CHK005 Is "changed" defined exactly (the node and everything downstream, by content key)? [Clarity, Spec §Clarifications Q3, FR-A23-305]
- [x] CHK006 Is the tolerance of each pixel reference and where references are sampled stated? [Clarity, Spec §SC-A23-301 (corrected: sampled at pixel centres in 0…1 coordinates; blur farther than its radius from the edges)]
- [x] CHK007 Is the inset's position and size defined independently of the device? [Clarity, Spec §Clarifications Q4]

## Requirement Consistency

- [x] CHK008 Do the edge cases agree with the checker of A23-P01 (nodes not reaching the output compile into nothing)? [Consistency, Spec §Edge Cases, FR-A23-301]
- [x] CHK009 Is "never from a control" consistent with the next-frame compile rule of A23-P02's precedent? [Consistency, Spec §FR-A23-305, Clarifications Q3]

## Acceptance Criteria Quality

- [x] CHK010 Are the success criteria countable (tolerances, slot counts, a 5-pass chain in 2 slots, one compile for N edits, 10 rebuilds)? [Measurability, Spec §SC-A23-301–306]

## Architecture Ownership and Lifecycle

- [x] CHK011 Is it stated that every pass runs through VisualCore inside the host's context and that the budget is checked before allocation? [Coverage, Spec §FR-A23-304, FR-A23-307]
- [x] CHK012 Are setup, teardown, context rebuild and resize behaviours of the preview specified? [Coverage, Spec §Clarifications Q5, US5, plan Lifecycle]
- [x] CHK013 Are the reused VisualCore declarations named and checked in code, with no VisualCore change? [Dependency, Spec §Clarifications facts, contracts/preview.md]

## Privacy, Performance and Release

- [x] CHK014 Is the absence of network, permission, stored files and images stated? [Coverage, Spec §Negative Requirements]
- [x] CHK015 Are performance claims avoided, with device measurement deferred to the campaign? [Non-Functional, Spec §Assumptions, Negative Requirements]
- [x] CHK016 Is the candidate (not available) status kept? [Coverage, Spec §Canonical overrides]

## Notes

- One correction during evaluation: SC-A23-301 now says where references are sampled and what "away from the edges"
  means.
