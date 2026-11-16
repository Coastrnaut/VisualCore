# Content Requirements Quality Checklist: Interactive Anatomy — Phase 01

**Purpose**: Unit tests for the requirements of A17-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK005).

## Completeness and clarity

- [x] CHK001 Are all schema fields of region, structure and manifest named? [Spec §FR-A17-101, data-model] — yes.
- [x] CHK002 Is the structure list fixed with ids, names and layers? [Clarifications Q1] — yes (14 structures, 3 layers).
- [x] CHK003 Are all refusal kinds enumerated with what they mean? [Clarifications Q3, FR-A17-103] — yes.
- [x] CHK004 Is the label-to-structure-to-mesh rule stated so that it can be checked? [Clarifications Q4, US2] — yes.
- [x] CHK005 Is "plain-language description" bounded in length and content, so that no clinical statement slips in? [Gap] — failed (only "plain words" was said); FR-A17-107 now limits it to 1–3 sentences, 400 characters, form, position and connections, and refuses clinical words.

## Provenance and claims

- [x] CHK006 Is every source kind given a license, with the allowed set stated? [Clarifications Q2] — yes (public-domain, original, facts).
- [x] CHK007 Is the review status and its sentence stated, with the review left to a person? [FR-A17-104, research D3] — yes.

## Privacy

- [x] CHK008 Is it stated that the content is bundled and that nothing is collected or sent? [Negative Requirements] — yes.

## Architecture ownership

- [x] CHK009 Is the core kept pure, depending only on Foundation and VisualCoreMath? [plan Constitution IV] — yes.
- [x] CHK010 Is the hand-over to A17-P02 (building every declared mesh) stated as a check? [Assumptions, Clarifications Q4] — yes.

## iOS lifecycle and release

- [x] CHK011 Is it stated that nothing appears in the app in this phase (no target or registration)? [FR-A17-106, Clarifications Q5] — yes.
- [x] CHK012 Is the size cap of the content resource quantified? [Clarifications Q3] — yes (256 KB).

## Testability and performance

- [x] CHK013 Is each refusal kind required to have a test that names it? [SC-A17-102] — yes.
- [x] CHK014 Is the test-time bound stated? [SC-A17-104] — yes.

## Notes

`/speckit-implement` reads this checklist and does not change its markers.
