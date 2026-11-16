# Release Requirements Quality Checklist: Molecular Explorer — Phase 06

**Purpose**: Unit tests for the requirements of A15-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK010).

## Privacy

- [x] CHK001 Are "no permission" and "no usage string" stated as requirements? [FR-A15-601] — yes.
- [x] CHK002 Is the scanned list of forbidden uses enumerated, photo library and image picker included? [FR-A15-602, Clarifications Q3] — yes.
- [x] CHK003 Does the privacy note's required content (the four files and the session state, place, the picked file read once, deletion, credits with licences) appear? [FR-A15-604, research D1] — yes.

## Data and recovery

- [x] CHK004 Are the sample files' kinds, forms and expected answers enumerated? [FR-A15-610, data model] — yes.
- [x] CHK005 Is the failure seam's behaviour and the byte-identical rule for all stored files defined? [FR-A15-611, Clarifications Q5] — yes.
- [x] CHK006 Are the schema examples (1–3) and their target schema stated? [FR-A15-612, Clarifications Q5] — yes.
- [x] CHK007 Are the empty recent list and a failure right after an import defined? [Spec §Edge Cases] — yes.

## Release documents

- [x] CHK008 Are the refused words enumerated, chemistry claims (safety, toxicity, medical) included? [FR-A15-621, Clarifications Q2] — yes.
- [x] CHK009 Are the checklist's owner-action and device rows named? [FR-A15-620, Clarifications Q1] — yes.
- [x] CHK010 Is the artifact inventory's content defined? [FR-A15-620] — failed (only "an artifact inventory" was required); FR-A15-620 now lists the release documents, the sealed evidence of A15-P00 to A15-P06, the scan scripts and the interface suites.
- [x] CHK011 Is every store claim required to name an existing test? [FR-A15-620, Clarifications Q2] — yes.
- [x] CHK012 Are known limitations' required items (device-only items, library size, inference rule, import limits) listed? [FR-A15-622] — yes.
- [x] CHK013 Is a device-campaign plan with named rows required? [Clarifications Q5, research D5] — yes.

## Interface, lifecycle and performance

- [x] CHK014 Are the interface journeys and their 60-second limit specified per suite, with no document picker presented? [FR-A15-630, Clarifications Q4, Negative Requirements] — yes.
- [x] CHK015 Are the release build checks named? [FR-A15-631, plan Evidence] — yes.
- [x] CHK016 Are accessibility facts proved so far and pending audits required in the checklist? [FR-A15-623] — yes.
- [x] CHK017 Are measured performance claims, per-app listings and owner-only actions excluded? [Negative Requirements] — yes.
- [x] CHK018 Can every success criterion be checked on the simulator and in the repository? [SC-A15-601–605, quickstart] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
