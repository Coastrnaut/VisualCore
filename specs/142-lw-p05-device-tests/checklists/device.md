# Device Tests Requirements Quality Checklist: Living Wallpapers — Phase 05

**Purpose**: Unit tests for the requirements of A19-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK005).

## Completeness

- [x] CHK001 Are the eight campaign rows named with what each records, on which devices and with which threshold? [Clarifications Q3, FR-A19-503] — yes.
- [x] CHK002 Are the interface journeys named with their steps and the identifiers they read? [Q1, contracts/interface.md] — yes.
- [x] CHK003 Is the regression fixture's phrase list and the place it is applied (shown texts, help sheet) specified? [Q5, FR-A19-502] — yes.

## Clarity and measurability

- [x] CHK004 Is the notice path made testable on a simulator without changing shipping behaviour? [Q2, research D2] — yes (`-lwExportLimit` under automation only, with a unit test).
- [x] CHK005 Are the interface test's expected numbers exact for the limited export? [contracts/interface.md] — failed (the contract allowed either orientation and no offered size); corrected to portrait 1206 × 2622 with the offered 470 × 1024 from `ExportGeometry`.
- [x] CHK006 Are the interface test time limits stated? [SC-A19-501] — yes (under 60 s each).

## Device rules and privacy

- [x] CHK007 Is it stated that nothing runs on a device before ImplementationLock-100, and that D3 stays on iPadOS 26.5? [Assumptions, Negative Requirements] — yes.
- [x] CHK008 Is any simulator number excluded from being device evidence, and are owner actions (a device in hand, the Photos prompt) recorded as such? [FR-A19-504, Edge Cases] — yes.
- [x] CHK009 Are the Photos prompt and its declined path campaign rows rather than simulator claims? [Q3 LW-D6, LW-D7] — yes.

## Architecture and lifecycle

- [x] CHK010 Is it stated that no VisualCore change is needed and the GPU context stays in the host? [Q4, FR-A19-505] — yes.
- [x] CHK011 Are the audits at the largest text size deferred to the campaign with their row? [Edge Cases, LW-D8] — yes.

## Release

- [x] CHK012 Is the new chunk's serial run and its place in the release checks specified? [plan, Q1] — yes (`a3` in `SERIAL_CHUNKS`).

## Notes

- `/speckit-implement` reads these markers and does not change them.
