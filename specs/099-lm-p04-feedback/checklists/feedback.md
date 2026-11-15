# Feedback Requirements Quality Checklist: Light Maze — Phase 04

**Purpose**: Unit tests for the requirements of A13-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); two items failed and were corrected
before this record (CHK008, CHK009).

## Completeness

- [x] CHK001 Is the Phase 04 gate (glow and colour cues without hiding beam connectivity) required with a measurable outcome? [Spec §Canonical overrides, FR-A13-431, SC-A13-404] — yes.
- [x] CHK002 Is the hint's choice of tile, its words and its refusal fully stated? [FR-A13-401, Clarifications Q1, contract] — yes.
- [x] CHK003 Are all four parts of the success cue (visual, sound, haptic, words) specified with their values? [FR-A13-420, Clarifications Q3, contract] — yes.
- [x] CHK004 Are the nine board states and their signs enumerated? [Clarifications Q4, data model] — yes.
- [x] CHK005 Is the board description's content and order specified? [FR-A13-410, Clarifications Q5] — yes.

## Architecture ownership

- [x] CHK006 Is the reuse of framework planners, sign check, contrast ratio, sound and feedback route required with no upstream change? [Plan Technical Context, Constitution II] — yes.
- [x] CHK007 Is the hint's place (engine action changing only the selection) stated with its effect on replays and best counts? [Clarifications Q1, research D2] — yes.

## Clarity and consistency

- [x] CHK008 Do the summary words agree between the spec, data model and contract? [Clarifications Q2, data model, contract] — failed (data model "N of M targets lit; solved" against the contract's sentence); data model corrected.
- [x] CHK009 Does the beam-path wording agree between story 2 and FR-A13-410 (start, turns, end per branch)? [US2/AC1, FR-A13-410] — failed (story said "turns or ends"); spec corrected.
- [x] CHK010 Is "brightens once" quantified (0.6 s, one rise and fall, peak 1.5)? [FR-A13-421, research D5] — yes.
- [x] CHK011 Is the contrast threshold quantified and its reference colour named (3 : 1 against the board)? [FR-A13-431] — yes.

## iOS lifecycle and recovery

- [x] CHK012 Are suspension during a cue and resume of a solved board addressed? [FR-A13-421, Edge Cases, plan Lifecycle] — yes.
- [x] CHK013 Are muted sound, unavailable haptics and VoiceOver off addressed? [Edge Cases, Clarifications Q2] — yes.
- [x] CHK014 Is the absence of data-format change (no migration) stated with rollback? [Plan Migration, Rollback] — yes.

## Accessibility and privacy

- [x] CHK015 Are Hint and Describe required as native controls with labels and the canvas value as a summary? [FR-A13-402, 411, contract] — yes.
- [x] CHK016 Are Reduce Motion and Reduce Flashing behaviours each specified? [FR-A13-421, US3/AC2] — yes.
- [x] CHK017 Are code-made sound only, no flashing and no network stated? [Negative Requirements] — yes.

## Testability and performance

- [x] CHK018 Can every success criterion be checked without a device? [SC-A13-401–405, quickstart] — yes.
- [x] CHK019 Is the description length bounded with the largest board at the caps? [FR-A13-410, research D7] — yes.
- [x] CHK020 Is the cue bounded (one per transition, haptic rate limit) without timing claims? [SC-A13-403, US3/AC3] — yes.

## Notes

- 20 items evaluated on 2026-11-15; two corrected. `/speckit-implement` reads these markers and does not change them.
