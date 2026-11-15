# Effects Requirements Quality Checklist: Neon Arcade — Phase 03

**Purpose**: Unit tests for the requirements of A10-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are the Phase 03 gates (flows with the run's score; swept collision at high speed; context ownership in the host) required with acceptance scenarios? [Spec §US1, §US3, FR-A10-310, 330] — yes.
- [x] CHK002 Are every screen, every allowed transition and the refusal for the others defined? [Clarifications Q2, FR-A10-310] — yes.
- [x] CHK003 Are every effect, sound and haptic named with numbers (counts, durations, frequencies, gains)? [Clarifications Q3, Q4] — yes.
- [x] CHK004 Are the sound-effect description limits and the player's behaviour defined? [Clarifications Q1, FR-A10-301, 302] — yes.

## Clarity and measurability

- [x] CHK005 Are "bounded" and "click-free" quantified? [Spec §SC-A10-302] — yes (peak ≤ 0.9, 2 ms edges within 5 %).
- [x] CHK006 Is "effects never change the game" measurable? [Spec §SC-A10-304] — yes (identical digests with effects, sound and haptics on/off).
- [x] CHK007 Are the high-speed cases quantified? [Spec §SC-A10-305, Clarifications Q5] — yes (20, 50, 100 units/s; side pass 1.5 units).

## iOS lifecycle and recovery

- [x] CHK008 Is the behaviour when the person leaves the app mid-game specified? [Spec §Edge Cases; constitution A10 Bounded resources] — failed at first (only "playback stops"); an edge case now requires a recorded pause on suspension, so the paused screen returns and nothing advances.
- [x] CHK009 Are interruption and background behaviour of sound specified? [Clarifications Q1, Edge Cases] — yes (stopAll, nothing queued).
- [x] CHK010 Is migration of schema-2 (and older) saved state specified? [Clarifications Q2, plan Migration] — yes.

## Architecture ownership

- [x] CHK011 Is it stated which parts go to VisualCore (synth, player) and which stay app-local (flow, effect plans, sound choices)? [Spec overrides, plan] — yes.

## Accessibility and privacy

- [x] CHK012 Are Reduce Motion and reduced flashing requirements stated with their effect? [FR-A10-311, 321] — yes (0 s transitions; outline instead of tint).
- [x] CHK013 Is the absence of any permission, recording and network stated, with the audio category that guarantees it? [Clarifications Q1, Negative Requirements] — yes (ambient, no input).

## Release constraints and licenses

- [x] CHK014 Are recorded or purchased sounds excluded and sounds required to be code? [Negative Requirements; constitution A10] — yes.

## Testability and performance

- [x] CHK015 Is every success criterion tied to a runnable check with time bounds? [SC-A10-301–306, quickstart] — yes.
- [x] CHK016 Are per-step effect and voice caps stated? [Clarifications Q1, Q3] — yes (3 bursts, 2 sounds, 256 particles, 4 voices).

## Notes

- 16 items evaluated on 2026-11-14; CHK008 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
