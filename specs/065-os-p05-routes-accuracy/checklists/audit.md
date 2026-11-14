# Audit Requirements Quality Checklist: Oscilloscope Studio — Phase 05

**Purpose**: Unit tests for the requirements of A08-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK005).

## Completeness

- [x] CHK001 Are all three manual gates (demo generator audited; freeze metadata fixture; context in the host) required? [Spec overrides, FR-A08-510, 531] — yes.
- [x] CHK002 Are the three gaps built here (G-STEREOMIC, G-ACCURACY, G-MEASUREA11Y) and the quality levels named with their owners? [Spec overrides, FR-A08-501, 510, 520, 521] — yes.
- [x] CHK003 Are the device-only items (stereo routes, latency, rates, thermal) named and deferred with a record? [FR-A08-530, Clarifications Q5] — yes.

## Clarity

- [x] CHK004 Are the accuracy cases and their tolerances listed (frequencies, waveforms, sweep times; bin, sample, 1.5 dB)? [Clarifications Q2, FR-A08-510] — yes.
- [x] CHK005 Is the sweep tolerance achievable and measurable for a frequency that changes within one analysed frame? [Story 1 AC3] — failed at first ("within one bin of the instantaneous frequency" ignores the 85 ms frame); corrected to the frame's frequency range widened by one bin, at 0.5 s, 1 s and 1.5 s.
- [x] CHK006 Are the quality levels quantified (columns 1, ½, ¼; analysis every 1, 2, 4 frames)? [FR-A08-521, Clarifications Q3] — yes.

## Consistency

- [x] CHK007 Do the two-channel microphone's permission and interruption rules match the mono source's? [Story 2 AC3, FR-A08-501, Clarifications Q1] — yes.
- [x] CHK008 Is it consistent that quality levels never change digests or frozen samples? [Story 3 AC3, Edge Cases] — yes.

## Architecture ownership

- [x] CHK009 Is the new VisualCore type placed beside the mono source without changing it, with a test seam? [Clarifications Q1, research D1] — yes.
- [x] CHK010 Is the lesson that the core must declare its levels written into the requirements? [FR-A08-521] — yes.

## iOS lifecycle and accessibility

- [x] CHK011 Are route changes, interruptions and resume defined for the microphone? [Edge Cases, FR-A08-501] — yes.
- [x] CHK012 Are the announced events, the 1.5 s pacing and the VoiceOver-only rule defined? [FR-A08-520, Clarifications Q4] — yes.

## Privacy and truthfulness

- [x] CHK013 Are no recording, the same permission and string, and no latency or calibrated claims stated? [Negative Requirements, FR-A08-530] — yes.

## Testability and performance

- [x] CHK014 Is every success criterion tied to a runnable check with numbers? [SC-A08-501–505, quickstart] — yes.
- [x] CHK015 Are performance numbers kept out of this phase except arithmetic on columns and intervals? [Assumptions, Plan Technical Context] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK005 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
