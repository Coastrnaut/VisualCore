# Requirements Quality Checklist: A06-P05 performance and accessibility

**Purpose**: Unit tests for the Phase 05 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer judged the requirement text satisfactory. Evaluated by the lead under the owner's standing
delegation (Canonical override); evaluations follow each item. `/speckit-implement` reads these markers and does not
change them.

## Requirement Completeness

- [x] CHK001 Are all three quality levels specified with window size and band count? [Completeness, Spec §FR-A06-501] — yes.
- [x] CHK002 Is the metric text's exact format defined, including silence and non-finite values? [Completeness, Spec §Clarifications 2] — yes.
- [x] CHK003 Are palette names, count and where they persist specified? [Completeness, Spec §FR-A06-512] — state, presets, actions.
- [x] CHK004 Is the transition fixture's event sequence and expected end state defined? [Completeness, Spec §User Story 4] — yes.

## Requirement Clarity

- [x] CHK005 Is the out-of-range level rule stated without contradiction? [Clarity → fixed, Spec §FR-A06-501] — failed first ("refuse … by clamping"); now "clamp".
- [x] CHK006 Is the expected strongest region for the 1 kHz example correct for the band layout? [Clarity → fixed, Spec §User Story 1 AC1] — failed first (said low-mid; 1 kHz is band 8 → high-mid); corrected.
- [x] CHK007 Is the rate limit quantified? [Clarity, Spec §FR-A06-511] — 1 per 2 s, changed text only, VoiceOver running.

## Requirement Consistency

- [x] CHK008 Is the "approximate visual aids" labelling tied to a visible place? [Consistency → fixed, Spec §FR-A06-510, 520] — failed first; now a controls section titled "Sound metrics (approximate)".
- [x] CHK009 Do preset format 2 and state schema 3 agree on the palette range? [Consistency, Spec §FR-A06-512] — 0…2 both.
- [x] CHK010 Is G-SIGNALTEXTURE's closure consistent with out-of-scope and the contract? [Consistency, Spec §Overrides, Out of Scope] — adapted, evidence named.

## Acceptance Criteria Quality

- [x] CHK011 Is the per-window cost bound numeric and its CI handling stated? [Measurability, Spec §SC-A06-502, Clarifications 5] — < 0.5 ms locally; reported on CI.
- [x] CHK012 Are announcement counts measurable over a fixed timeline? [Measurability, Spec §SC-A06-503] — 10 s scripted timeline.

## Scenario & Edge Case Coverage

- [x] CHK013 Are quality changes while running, non-finite metrics, VoiceOver off and invalid palette values covered? [Coverage, Spec §Edge Cases] — yes.
- [x] CHK014 Are migration paths (schema 2, preset format 1) covered? [Recovery, Spec §User Story 2 AC2–3] — yes.

## Architecture Ownership & Lifecycle

- [x] CHK015 Is the split VisualCore (quality) vs app (metrics, palettes) stated? [Constitution II, Plan §Summary] — yes.
- [x] CHK016 Is extractor rebuilding on tier change tied to the frame lifecycle? [Plan §Lifecycle] — yes.
- [x] CHK017 Is release of host and capture on close required? [Spec §FR-A06-514] — yes.

## Non-Functional: Accessibility, Performance, Privacy, Release

- [x] CHK018 Is information available without colour or motion? [Accessibility, Spec §Negative Requirements] — text metrics.
- [x] CHK019 Is the performance bound deferred to devices where only devices can measure it? [Spec §Assumptions] — device campaign.
- [x] CHK020 Are privacy and claim limits restated? [Spec §FR-A06-520] — yes.
- [x] CHK021 Are test durations bounded? [Spec §SC-A06-506] — < 10 s.

## Notes

- Three items failed on first evaluation (CHK005, CHK006, CHK008); the spec was corrected the same day.
