# Requirements Quality Checklist: A06-P02 feature analysis

**Purpose**: Unit tests for the Phase 02 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer judged the requirement text satisfactory. Evaluated by the lead under the owner's standing
delegation (Canonical override); evaluations follow each item. `/speckit-implement` reads these markers and does not
change them.

## Requirement Completeness

- [x] CHK001 Are all four MVP signals (RMS, peak, spectrum, smoothed beat energy) each tied to a requirement? [Completeness, Spec §FR-A06-201, 202, 204, 205] — yes: 201 (RMS/peak), 202 (spectrum bands), 204/205 + clarification (beat energy).
- [x] CHK002 Is the silence fixture stated for both the analysis and the display? [Completeness, Spec §FR-A06-206, SC-A06-205] — yes.
- [x] CHK003 Are the features' relation to persisted state specified? [Completeness, Spec §FR-A06-213] — not state; digest/snapshot/manifest unchanged.
- [x] CHK004 Is the behaviour defined when a source delivers no new samples between frames? [Gap → fixed] — failed first: added an edge case (same window, flux 0, beat decays).

## Requirement Clarity

- [x] CHK005 Is "band" defined with count, spacing, range and bin assignment? [Clarity, Spec §FR-A06-202, Clarifications] — yes (16, log, 40 Hz…min(16 kHz, fs/2), bin centre, ≥ 1 bin).
- [x] CHK006 Is the onset threshold quantified? [Clarity, Spec §Clarifications] — 1.5 × mean of 43 + 1e-4, 0.1 s.
- [x] CHK007 Are the level words tied to dBFS thresholds? [Clarity, Spec §FR-A06-212] — −40/−20 dBFS.
- [x] CHK008 Is "smoothed" quantified with time constants in seconds? [Clarity, Spec §Key Entities] — 0.01 s / 0.25 s.

## Requirement Consistency

- [x] CHK009 Are the level words consistent with A06-P01's existing description? [Consistency, Clarifications] — same words and thresholds.
- [x] CHK010 Does "no onset on a steady tone" agree with the first window after silence producing flux? [Conflict → fixed] — failed first: SC-A06-203 now excludes the first window.
- [x] CHK011 Is the beat-meter acceptance in the experience consistent with per-frame (not per-hop) analysis? [Conflict → fixed] — failed first: story 1 scenario 2 now counts ≥ 3 beats in 2 s; hop-exact timing stays in the host fixtures.

## Acceptance Criteria Quality

- [x] CHK012 Do all success criteria carry numeric tolerances? [Measurability, Spec §SC-A06-201…206] — 1e-6, 1e-4, one hop, ± one frame, identical pixels.
- [x] CHK013 Is frame-rate independence measurable? [Measurability, Spec §SC-A06-204] — at 30 and 120 updates/s.

## Scenario & Edge Case Coverage

- [x] CHK014 Are short windows, other sample rates, clipping, non-finite samples, source switch and frame drops covered? [Coverage, Spec §Edge Cases] — yes.
- [x] CHK015 Is recovery after a source switch specified (no lingering beat)? [Recovery, Spec §FR-A06-211] — reset on change.

## Architecture Ownership & Lifecycle

- [x] CHK016 Is the split between VisualCore (analysis) and the experience (display, copy) stated? [Constitution II, Plan §Summary] — yes.
- [x] CHK017 Is it stated where analysis runs (render side, never the audio callback)? [Spec §Assumptions, Negative Requirements] — yes.
- [x] CHK018 Are creation, reset and release of the analysis tied to experience lifecycle events? [Plan §Lifecycle] — setup/reset/teardown.

## Non-Functional: Privacy, Performance, Accessibility, Release

- [x] CHK019 Are privacy constraints restated (no recording, storage, upload)? [Spec §FR-A06-220] — yes.
- [x] CHK020 Is a performance bound stated or explicitly deferred with reason? [Gap → fixed] — failed first: Assumptions now bound the work by construction and defer the measured bound to Phase 05 (G-AUDIOBUDGET).
- [x] CHK021 Are accessibility requirements defined for the new visuals? [Spec §FR-A06-212] — spoken level and beat.
- [x] CHK022 Are claims that the store copy must avoid identified? [Spec §FR-A06-220] — no hearing, health or accuracy claims.
- [x] CHK023 Are test-duration limits stated? [Spec §SC-A06-206] — each new test < 10 s.

## Dependencies & Assumptions

- [x] CHK024 Are dependencies on A06-P01 types named? [Plan §Technical Context] — verified APIs listed.
- [x] CHK025 Is the assumption that no audio files are bundled recorded? [Spec §Assumptions] — synthetic signals only.

## Notes

- Four items failed on first evaluation (CHK004, CHK010, CHK011, CHK020); the spec was corrected the same day and they
  now pass.
