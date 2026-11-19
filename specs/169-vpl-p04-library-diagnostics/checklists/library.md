# Library Requirements Checklist: Visual Programming Lab — Phase 04 Save/load, examples and diagnostics

**Purpose**: Unit tests for the requirements of A23-P04 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) found the requirement-quality criterion
satisfied; it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are the file names, envelopes, sizes, caps and messages of the library stated? [Completeness, Spec §Clarifications Q1, data-model]
- [x] CHK002 Is every unreadable-file reason named, with the rule that such files are never deleted automatically? [Completeness, Spec §FR-A23-403, Clarifications Q1]
- [x] CHK003 Are the examples named, with their graphs and their licence record? [Completeness, Spec §Clarifications Q4, FR-A23-404]
- [x] CHK004 Is each checker issue mapped to the node or nodes it marks, with its sentence? [Completeness, Spec §Clarifications Q5, FR-A23-405]

## Requirement Clarity

- [x] CHK005 Is "preserve" defined exactly (identities, connections, values, positions; equal fingerprint)? [Clarity, Spec §FR-A23-402, SC-A23-401]
- [x] CHK006 Is the migration claim limited to what exists (one format, the chain exercised by a synthetic step)? [Clarity, Spec §Clarifications Q3]

## Requirement Consistency

- [x] CHK007 Does opening go through the same restore path as a session restore, so a bad file cannot reach the core? [Consistency, Spec §Clarifications Q2, research D2]
- [x] CHK008 Are the library's caps consistent with the storage quota (24 files of at most 80 KiB under 16 MiB and 64 files)? [Consistency, Spec §Clarifications facts, Q1]

## Acceptance Criteria Quality

- [x] CHK009 Are the success criteria countable (fingerprints equal, samples kept, bounds at and one past, exactly the named nodes)? [Measurability, Spec §SC-A23-401–406]

## Scenario and Edge Coverage

- [x] CHK010 Are the quota-exceeded and partial-write cases covered? [Coverage, Spec §Edge Cases, FR-A23-406]
- [x] CHK011 Is opening over unsaved work specified? [Coverage, Spec §Edge Cases (added: a replace confirmation)]
- [x] CHK012 Is the relaunch case covered by the session snapshot? [Coverage, Spec §Edge Cases, Clarifications Q2]

## Accessibility, Privacy and Release

- [x] CHK013 Are diagnostics shown by shape as well as colour, and spoken? [Coverage, Spec §Clarifications Q5, FR-A23-405]
- [x] CHK014 Is the absence of sharing, import, export, cloud storage and network stated? [Coverage, Spec §Negative Requirements]
- [x] CHK015 Is the candidate (not available) status kept, with no VisualCore change? [Coverage, Spec §Canonical overrides, Negative Requirements]
- [x] CHK016 Are tests bounded in time with no device claim? [Non-Functional, Spec §SC-A23-406, Assumptions]

## Notes

- One correction during evaluation: an edge case and identifier (`library-replace-confirm`) for opening over unsaved
  work, after Digital Zen Garden.
