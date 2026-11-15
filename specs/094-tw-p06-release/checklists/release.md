# Release Requirements Quality Checklist: Tiny Worlds — Phase 06

**Purpose**: Unit tests for the requirements of A12-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK009).

## Completeness

- [x] CHK001 Are all three Phase 06 gates (checklist and inventory; attached results with device rows listed; unsupported promises removed) required? [Spec §Canonical overrides, FR-A12-620, 621] — yes.
- [x] CHK002 Are every manual Phase 06 deliverable (privacy strings, accessibility, asset and credit review, migration, CPU/GPU/device tests, crash recovery, build/archive instructions) mapped to a requirement? [Spec §Traceability] — yes.
- [x] CHK003 Are the stored files, their location, deletion paths and credits required in the privacy note? [FR-A12-604; Research D1] — yes.
- [x] CHK004 Are the release documents and the release configuration fields defined? [FR-A12-620; Contract] — yes.

## Privacy

- [x] CHK005 Is the forbidden-API list enumerated exactly? [Clarifications Q3, FR-A12-602] — yes (13 patterns).
- [x] CHK006 Is "no permission and no usage string" stated as a requirement with a check? [FR-A12-601, SC-A12-601] — yes.

## Architecture ownership and lifecycle

- [x] CHK007 Is the test-only failure seam scoped (internal, one draw, no behaviour change otherwise)? [Plan §Lifecycle; Research D3] — yes.
- [x] CHK008 Are graphics ownership and the one-app boundary unchanged (no new target, no listing)? [Spec §Canonical overrides; Out of Scope] — yes.

## Testability and coverage

- [x] CHK009 Is every edge case covered by a requirement? [Spec §Edge Cases] — failed (picture/world mismatch had no requirement); FR-A12-610 and research D3 now require it.
- [x] CHK010 Are sample-file outcomes stated per form (opens, `newer-version`, `damaged`)? [Clarifications Q5; Data model] — yes.
- [x] CHK011 Are the interface journeys, chunk and per-test limit specified? [Clarifications Q4, FR-A12-630, SC-A12-604] — yes.
- [x] CHK012 Are refused claim words listed and the claim → test rule stated? [Clarifications Q2, FR-A12-621, SC-A12-603] — yes.

## Performance and release constraints

- [x] CHK013 Are measured performance claims excluded and device measurements deferred as {device} rows? [FR-A12-622, 641; Negative Requirements] — yes.
- [x] CHK014 Are owner-only steps recorded as owner actions rather than performed? [FR-A12-640; Edge Cases] — yes.
- [x] CHK015 Are the checklist statuses limited to the checker's three? [Clarifications Q1; Data model] — yes.
- [x] CHK016 Are the accessibility facts proved and the audits pending both required in the checklist? [FR-A12-623] — yes.
