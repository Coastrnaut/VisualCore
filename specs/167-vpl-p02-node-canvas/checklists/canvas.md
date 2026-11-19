# Canvas Requirements Checklist: Visual Programming Lab — Phase 02 Node canvas and connections

**Purpose**: Unit tests for the requirements of A23-P02 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) found the requirement-quality criterion
satisfied; it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Is every edit (add, move, remove, select, connect, disconnect) specified with its action values and refusals? [Completeness, Spec §Clarifications Q1, FR-A23-202]
- [x] CHK002 Is the starter graph defined exactly (kinds, identities, positions)? [Completeness, data-model LabCore, FR-A23-201]
- [x] CHK003 Are the canvas geometry numbers (box, rows, targets, wire handles) stated? [Completeness, Spec §Clarifications Q2]
- [x] CHK004 Is each refusal's sentence specified by what it names (types, loop, fed input, limit, second output, direction)? [Completeness, Spec §FR-A23-203]

## Requirement Clarity

- [x] CHK005 Is the touch mapping unambiguous between tap, move, wire drag, pan and pinch (with the 10-point tap threshold)? [Clarity, Spec §Clarifications Q3]
- [x] CHK006 Are the zoom and pan bounds quantified (0.5…2; ±4,096)? [Clarity, Spec §FR-A23-204, Clarifications Q3]

## Requirement Consistency

- [x] CHK007 Do the canvas and the list form share one rule set for refusals? [Consistency, Spec §US4, research D1]
- [x] CHK008 Is view state kept out of the snapshot and digest, consistent with "view changes leave the graph unchanged"? [Consistency, Spec §Clarifications Q1, Q3, SC-A23-203]

## Acceptance Criteria Quality

- [x] CHK009 Are the success criteria countable (the journey graph's fingerprint, refusal fixtures, 44-point targets, 10 rebuilds byte-identical)? [Measurability, Spec §SC-A23-201–206]

## Architecture Ownership and Lifecycle

- [x] CHK010 Is it stated that the only GPU drawing is a VisualCore full-screen scene inside the presenter's calls? [Coverage, Spec §FR-A23-206, Clarifications Q4]
- [x] CHK011 Are context loss, resize and interrupted touches covered? [Coverage, Spec §US5, Edge Cases (added: an interrupted touch)]
- [x] CHK012 Are the reused VisualCore declarations named and checked in code, with no VisualCore change? [Dependency, Spec §Clarifications facts, contracts/experience.md]

## Accessibility, Privacy and Release

- [x] CHK013 Are spoken labels, non-colour port signs and an alternative to dragging specified? [Coverage, Spec §FR-A23-205, US4, Clarifications Q4]
- [x] CHK014 Is the absence of network, permission and stored files stated for this phase? [Coverage, Spec §Negative Requirements]
- [x] CHK015 Is the experience's candidate (not available) status and its manifest specified? [Coverage, Spec §FR-A23-207, Clarifications Q5]
- [x] CHK016 Is the frame cap and quality tier stated, with no unmeasured performance claim? [Non-Functional, Spec §Clarifications Q4, SC-A23-206]

## Notes

- One correction during evaluation: an edge case for an interrupted touch was added (the drag is dropped, the graph
  keeps its last completed move).
