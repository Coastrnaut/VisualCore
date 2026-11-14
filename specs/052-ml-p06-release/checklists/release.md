# Requirements Quality Checklist: A06-P06 release

**Purpose**: Unit tests for the Phase 06 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer judged the requirement text satisfactory. Evaluated by the lead under the owner's standing
delegation (Canonical override); evaluations follow each item. `/speckit-implement` reads these markers and does not
change them.

## Requirement Completeness

- [x] CHK001 Are all deliverable items of the manual (privacy strings, accessibility, credits, migration, device tests, crash recovery, build/archive) mapped to requirements? [Completeness, Spec §Traceability] — yes, accessibility via FR-A06-623 (added).
- [x] CHK002 Is the accessibility part of the deliverable covered by a requirement? [Gap → fixed, Spec §FR-A06-623] — failed first; FR-A06-623 adds the device-campaign accessibility audits.
- [x] CHK003 Are owner-only steps named and marked as blocked? [Completeness, Spec §FR-A06-640, Overrides] — yes.
- [x] CHK004 Is the fixture set enumerated with expected outcomes? [Completeness, Spec §Clarifications 3] — five files.

## Requirement Clarity

- [x] CHK005 Is "no unsupported promised feature" testable? [Clarity, Spec §FR-A06-621, SC-A06-605] — copy check with allow list.
- [x] CHK006 Are interface-test duration limits quantified? [Clarity, Spec §FR-A06-630] — < 60 s each.

## Requirement Consistency

- [x] CHK007 Is the one-permission rule consistent with the existing usage string? [Consistency, Spec §FR-A06-601, SC-A06-601] — yes.
- [x] CHK008 Is the copy allow list consistent with features that exist? [Consistency, Spec §Clarifications 1] — audio, music, microphone exist.

## Acceptance Criteria Quality

- [x] CHK009 Are success criteria numeric (counts, byte-identity, pass/fail)? [Measurability, Spec §SC-A06-601…606] — yes.

## Scenario & Edge Case Coverage

- [x] CHK010 Are name/id mismatches, quota limits, revoked permission and device-only items covered? [Coverage, Spec §Edge Cases] — yes.
- [x] CHK011 Is recovery after a drawing failure specified including reopen? [Recovery, Spec §FR-A06-611] — yes.

## Architecture & Lifecycle

- [x] CHK012 Is "no VisualCore change" stated with the exception rule? [Constitution II, Spec §FR-A06-640] — yes.

## Non-Functional: Privacy, Performance, Release

- [x] CHK013 Is the no-recording rule stated and scannable? [Privacy, Spec §FR-A06-602] — yes.
- [x] CHK014 Are performance claims prohibited unless measured on devices? [Spec §Negative Requirements, FR-A06-622/623] — yes.
- [x] CHK015 Is the build/archive instruction source named? [Spec §Traceability] — docs/release/build-and-archive.md.

## Notes

- One item failed on first evaluation (CHK002); FR-A06-623 was added the same day.
