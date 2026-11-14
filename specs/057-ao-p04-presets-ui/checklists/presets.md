# Presets Requirements Quality Checklist: Audio Odyssey — Phase 04

**Purpose**: Unit tests for the requirements of A07-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are both phase gates (input modes interface; stable, measurable demo response) required? [Spec §FR-A07-410, 420] — yes.
- [x] CHK002 Are save, apply, rename, delete and the built-ins' read-only rule all specified? [Spec §US1, FR-A07-401–403] — yes.
- [x] CHK003 Are damaged, newer and quota-failure cases specified with "nothing changes"? [Spec §Edge Cases, FR-A07-403, 404] — yes.

## Clarity

- [x] CHK004 Are name rules quantified (trim, 60 characters, "Untitled", suffix numbering ignoring case)? [Spec §FR-A07-403] — yes.
- [x] CHK005 Is "measurable response" quantified (25% of range within 2 s; determinism 1e-6)? [Spec §SC-A07-404] — yes.
- [x] CHK006 Is the demo trace's input path stated unambiguously in the design? [research.md D4] — failed at first (D4 contained an unresolved draft sentence); rewritten to state precomputed frames in Core and real demo analysis in the experience test.

## Architecture ownership

- [x] CHK007 Is the split between the pure preset type (Core) and the storage-bound store (experience) stated with the reason for not sharing A06's code? [Clarifications Q1] — yes.
- [x] CHK008 Is the apply path through validated actions specified, with refusal as a whole on any invalid value? [Clarifications Q3, data-model.md] — yes.

## iOS lifecycle and privacy

- [x] CHK009 Is the store's reload on activation and its storage (the experience's own, local) specified? [Plan Lifecycle, Spec §FR-A07-401] — yes.
- [x] CHK010 Is it stated that presets contain no audio and nothing is shared or sent? [Spec §FR-A07-440, Negative Requirements] — yes.

## Testability and performance

- [x] CHK011 Is every success criterion tied to a runnable check? [SC-A07-401–406, quickstart] — yes.
- [x] CHK012 Is timing in the fixture based on fixed steps rather than wall clock? [Clarifications Q4] — yes.

## Accessibility and release

- [x] CHK013 Are grouped, labelled controls and the source status specified for VoiceOver? [Spec §FR-A07-410, 430] — yes.
- [x] CHK014 Is the preset file format versioned with refusal of newer files? [Spec §FR-A07-404, research D3] — yes.
- [x] CHK015 Are claims about sound measurement excluded from preset names and copy? [Spec §FR-A07-440] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK006 corrected in research.md before marking. `/speckit-implement` reads these
  markers and does not change them.
