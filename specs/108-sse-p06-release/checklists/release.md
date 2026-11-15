# Release Requirements Quality Checklist: Solar System Explorer — Phase 06

**Purpose**: Unit tests for the requirements of A14-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK009).

## Privacy

- [x] CHK001 Are "no permission" and "no usage string" stated as requirements? [FR-A14-601] — yes.
- [x] CHK002 Is the scanned list of forbidden uses enumerated? [FR-A14-602, Clarifications Q3] — yes.
- [x] CHK003 Does the privacy note's required content (stored items, place, deletion, credits with licences) appear? [FR-A14-604, research D1] — yes.

## Data and recovery

- [x] CHK004 Are the sample files' forms and expected answers enumerated? [FR-A14-610, data model] — yes.
- [x] CHK005 Is the failure seam's behaviour and the byte-identical rule defined? [FR-A14-611, Clarifications Q5] — yes.
- [x] CHK006 Are the schema examples (1–3) and their target schema stated? [FR-A14-612, Clarifications Q5] — yes.
- [x] CHK007 Is the "no saved view yet" case defined? [Spec §Edge Cases] — yes.

## Copy and release documents

- [x] CHK008 Are the refused words enumerated, including the "not an ephemeris" exception? [FR-A14-621, Clarifications Q2] — yes.
- [x] CHK009 Are the checklist's owner-action and device rows named? [FR-A14-620] — failed (only the statuses were named); FR-A14-620 now names the owner-action rows (signing set-up, archive, upload; BLOCKED_OWNER_ACTION) and the device rows SSE-D1 to SSE-D6.
- [x] CHK010 Is every store claim required to name an existing test? [FR-A14-620, Clarifications Q2] — yes.
- [x] CHK011 Are known limitations' required items listed? [FR-A14-622] — yes.

## Interface and build

- [x] CHK012 Are the interface journeys and their 60-second limit specified per suite? [FR-A14-630, Clarifications Q4] — yes.
- [x] CHK013 Are the release build checks named? [FR-A14-631, plan Evidence] — yes.

## Accessibility and constraints

- [x] CHK014 Are accessibility facts proved so far and pending audits required in the checklist? [FR-A14-623] — yes.
- [x] CHK015 Are measured performance claims, per-app listings and owner-only actions excluded? [Negative Requirements] — yes.
- [x] CHK016 Can every success criterion be checked on the simulator and in the repository? [SC-A14-601–605, quickstart] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
