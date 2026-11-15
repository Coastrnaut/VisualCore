# Release Requirements Quality Checklist: Digital Aquarium — Phase 06

**Purpose**: Unit tests for the requirements of A09-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected in
the spec before this record (CHK005).

## Completeness

- [x] CHK001 Are all three manual Phase 06 gates required (checklist and inventory; results attached or pending rows; unsupported promises removed)? [Spec §Canonical overrides, FR-A09-620–622] — yes.
- [x] CHK002 Are privacy requirements complete (permission, scan, manifest, note)? [Spec §FR-A09-601–604] — yes.
- [x] CHK003 Are local data migration and crash recovery required? [Spec §FR-A09-610–612] — yes.
- [x] CHK004 Are build and archive instructions referenced? [Spec §FR-A09-640, plan release.json requiredDocs] — yes (shared build-and-archive document).
- [x] CHK005 Is accessibility (named in the manual's deliverable) required with automated and device parts? [Gap] — failed; corrected: FR-A09-623.

## Clarity and measurability

- [x] CHK006 Are the scanned uses enumerated? [Clarifications Q3] — yes.
- [x] CHK007 Are the refused realism and care words enumerated? [Clarifications Q2] — yes.
- [x] CHK008 Are the checklist statuses those the checker accepts? [Clarifications Q1] — yes.
- [x] CHK009 Are the sample files and their expected outcomes enumerated? [Clarifications Q4] — yes.
- [x] CHK010 Are the interface journeys and the time limit stated? [Clarifications Q5, SC-A09-604] — yes.

## Consistency

- [x] CHK011 Is the one-app rule (no per-app listing or pricing) consistent across stories and scope? [Spec §Canonical overrides, Out of Scope] — yes.
- [x] CHK012 Are device items consistently deferred to after ImplementationLock-100? [Spec §FR-A09-622, 641] — yes.
- [x] CHK013 Are owner steps consistently recorded and never done? [Spec §FR-A09-640, Negative Requirements] — yes.

## Edge cases

- [x] CHK014 Are a pending device row, an undone owner step, an untraced claim and a newer file covered? [Spec §Edge Cases] — yes.

## Privacy, performance and release

- [x] CHK015 Is "no measured claim" enforced by a check? [Spec §FR-A09-621] — yes (shared copy check).
- [x] CHK016 Are test durations bounded (10 s package, 60 s interface)? [Spec §SC-A09-604, 605] — yes.
- [x] CHK017 Does the phase add no permission or network? [Spec §FR-A09-601, 602] — yes.

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
