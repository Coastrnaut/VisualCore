# Requirements Quality Checklist: A05-P04 scene editing and export

**Purpose**: Unit tests for the requirements of feature 043 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release)
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement-quality criterion satisfied, not that code is done. Under the
owner's standing delegation the lead evaluated every item on 2026-11-13; evaluations are recorded inline.

## Requirement Completeness

- [x] CHK001 Are save, open, rename and delete each specified with their outcome? [Completeness, Spec §FR-A05-401–403] — yes.
- [x] CHK002 Is persistence across closing and reopening specified, including the quota case? [Completeness, Spec §FR-A05-404] — yes.
- [x] CHK003 Is the export size, aspect and format specified? [Completeness, Spec §FR-A05-410] — yes (PNG, long edge 2048, canvas aspect).
- [x] CHK004 Is the GPU-stability fixture specified with a measurable comparison? [Completeness, Spec §FR-A05-420, SC-A05-404] — yes.

## Requirement Clarity

- [x] CHK005 Is "deterministic" defined for saved compositions and for exports? [Clarity, Spec §FR-A05-402, 412, Clarifications] — yes (digest equality; identical decoded pixels).
- [x] CHK006 Are name rules (trim, length, empty, duplicates) unambiguous? [Clarity, Spec §FR-A05-401, Clarifications] — yes.

## Requirement Consistency

- [x] CHK007 Do the edge cases agree with the clarified naming rules? [Consistency, Spec §Edge Cases] — yes after the clarify edits.
- [x] CHK008 Is the restore rule for an out-of-bounds camera consistent with Phase 03? [Consistency, Spec §Edge Cases] — yes.

## Privacy

- [x] CHK009 Are the paths by which an exported picture leaves the app limited and stated? [Privacy, Spec §FR-A05-431] — yes (share sheet only).
- [x] CHK010 Is the metadata carried by an exported picture specified? [Gap, Privacy] — FAILED at first (not stated); corrected: FR-A05-431 now excludes location, device and time metadata.

## Architecture Ownership and Lifecycle

- [x] CHK011 Is it stated that export uses the host's context and no second renderer? [Spec §FR-A05-411, Negative Requirements] — yes.
- [x] CHK012 Is a failed export's effect on the live view and on files specified? [Exception Flow, Spec §FR-A05-413] — yes.
- [x] CHK013 Are damaged and newer-format saved files handled without data loss? [Recovery, Spec §FR-A05-405] — yes.

## Testability and Performance

- [x] CHK014 Are all success criteria measurable with thresholds? [Measurability, Spec §SC-A05-401–406] — yes.
- [x] CHK015 Is the memory cost of an export stated? [Gap, Performance] — FAILED at first; corrected: Assumptions give the 16 MiB bound and its release.
- [x] CHK016 Is the short-test bound stated? [Spec §SC-A05-406] — yes.

## Accessibility and Release

- [x] CHK017 Are labels, identifiers and button paths required for every new control? [Accessibility, Spec §FR-A05-430] — yes.
- [x] CHK018 Is the runner's scenario set required to stay valid? [Release, Spec §FR-A05-432, SC-A05-405] — yes.

## Notes

- 18 items, 2 failed and corrected in the spec before continuing; `/speckit-implement` reads this state but does not
  change it.
