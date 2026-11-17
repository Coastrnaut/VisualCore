# Clock Requirements Quality Checklist: Ambient Clock — Phase 01

**Purpose**: Unit tests for the requirements of A18-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK013).

## Completeness

- [x] CHK001 Are the preferences' fields, defaults and allowed values all specified? [Spec §FR-A18-103, Clarification Q4] — yes.
- [x] CHK002 Are all five time-change kinds named, with the single-recomputation rule? [Spec §FR-A18-102, SC-A18-103] — yes.
- [x] CHK003 Is the content of the spoken string specified (time, period or 24-hour form, date when shown)? [Spec §US3, Clarification Q5] — yes.

## Clarity

- [x] CHK004 Is "following each locale's conventions" made concrete with named fixture locales and their expected properties (12/24-hour, digits, order)? [Spec §FR-A18-104, Clarification Q3] — yes (en_US, de_DE, ja_JP, ar_EG).
- [x] CHK005 Is the update deadline defined precisely (next whole second or minute, in the clock's zone, strictly later)? [Spec §FR-A18-105, contracts/clock.md] — yes.
- [x] CHK006 Is the space difference before AM/PM between system versions handled in the comparison rule rather than left to chance? [Clarification Q3] — yes.

## Architecture ownership

- [x] CHK007 Is it stated which parts are VisualCore (source, monitor, the application names) and which are app-local (preferences, formatter, schedule, state)? [Clarification Q1, plan] — yes.
- [x] CHK008 Is the rule that the core reads no clock stated, with the actions through which time enters? [Clarification Q2, Spec §FR-A18-106] — yes (`time.set`, `time.changed`).
- [x] CHK009 Are the VisualCore obligations (docs, API baseline, tests, README row) listed? [Spec §FR-A18-108, plan] — yes.

## iOS lifecycle

- [x] CHK010 Are foreground return and significant time change covered even though the presenter receives no scene phase? [Clarification facts, Q1] — yes (the application names in the host).
- [x] CHK011 Are spring forward, fall back, a half-hour zone and midnight addressed as edge cases with fixtures? [Spec §Edge Cases, research D4] — yes.

## Privacy and release constraints

- [x] CHK012 Is the absence of permissions, network, location and interface in this phase stated? [Spec §Negative Requirements, FR-A18-109] — yes.

## Consistency

- [x] CHK013 Do the spec and the plan agree on when the reference regression runs for the VisualCore change? [Spec §FR-A18-108, SC-A18-105, plan] — failed (the spec required it in this phase, the plan deferred it to X-A18); FR-A18-108 and SC-A18-105 now say X-A18 (owner ruling of 2026-11-14).

## Testability and performance

- [x] CHK014 Is every success criterion tied to a runnable check, with the under-10-second bound and no wall-clock assert? [SC-A18-101–105, plan] — yes.
- [x] CHK015 Are invalid preference inputs enumerated with typed reasons and a size cap? [Clarification Q4, SC-A18-104] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
