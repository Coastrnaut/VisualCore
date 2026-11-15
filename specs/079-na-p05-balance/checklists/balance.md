# Balance Requirements Quality Checklist: Neon Arcade — Phase 05

**Purpose**: Unit tests for the requirements of A10-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are the Phase 05 gates (glow and particles constrained by readability; hitboxes readable across quality changes; context ownership in the host) required with acceptance scenarios? [Spec §US1, FR-A10-501–503, 522] — yes.
- [x] CHK002 Are the levels and every cap given in numbers, consistent across core, drawing and registration? [Clarifications Q1, FR-A10-501] — yes.
- [x] CHK003 Are the simulated players' rules and the balance targets stated? [Clarifications Q3, FR-A10-510] — yes.
- [x] CHK004 Are the device-campaign rows and the catalog text specified? [Clarifications Q4, Q5, FR-A10-520, 521] — yes.

## Clarity and measurability

- [x] CHK005 Is "readable" quantified with contrast ratios and a definition of the ratio? [Clarifications Q2, SC-A10-502] — yes.
- [x] CHK006 Is the precedence between Low Power Mode and the host's chosen level defined? [Spec §Edge Cases] — failed at first (only "Low Power Mode selects the lowest level"); the edge case now says level 0 under Low Power Mode, otherwise the host's level clamped to 0…2, presentation only.
- [x] CHK007 Is the reaction to a missed balance target defined? [Spec §Edge Cases, Clarifications Q3] — yes (tune, record, regenerate).

## Architecture ownership

- [x] CHK008 Is it stated that budgets, contrast and players are app-local and that the only shared change is the catalog script's optional summary? [plan Summary, research D4] — yes.

## iOS lifecycle

- [x] CHK009 Is a level change mid-run specified as presentation only, with particles above a lowered cap removed? [Spec §US1 AC2, Edge Cases] — yes.

## Privacy and release constraints

- [x] CHK010 Are benefit claims and unmeasured performance numbers excluded from the catalog entry and documents? [FR-A10-521, Negative Requirements] — yes.
- [x] CHK011 Are device measurements kept pending until ImplementationLock-100? [FR-A10-520, Edge Cases] — yes.
- [x] CHK012 Is the absence of a per-app store listing, screenshots and pricing stated? [Spec overrides, Out of Scope] — yes.

## Testability and performance

- [x] CHK013 Is every success criterion tied to a runnable check with time bounds? [SC-A10-501–505, quickstart] — yes.
- [x] CHK014 Is the balance simulation bounded (players × seeds × steps) to fit the test time limit? [Clarifications Q3, plan Performance] — yes (3 × 20 × ≤ 6,000 steps).

## Notes

- 14 items evaluated on 2026-11-14; CHK006 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
