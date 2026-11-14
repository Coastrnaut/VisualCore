# Requirements Quality Checklist: A06-P03 scenes and mapping

**Purpose**: Unit tests for the Phase 03 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer judged the requirement text satisfactory. Evaluated by the lead under the owner's standing
delegation (Canonical override); evaluations follow each item. `/speckit-implement` reads these markers and does not
change them.

## Requirement Completeness

- [x] CHK001 Are all three MVP scenes named with what each shows? [Completeness, Spec §User Story 1, FR-A06-310] — Bars, Rings, Geometry described.
- [x] CHK002 Are every scene's parameters, ranges and default mappings specified? [Completeness, Plan research D4] — yes, research D4 (spec defers to plan for numbers).
- [x] CHK003 Is the mapping's full formula (normalise, gain, clamp, smooth, map) specified? [Completeness, Spec §Clarifications] — yes.
- [x] CHK004 Is the hot-path fixture defined with a marking rule and an enforcement mechanism? [Completeness, Spec §FR-A06-320, Clarifications] — yes.
- [x] CHK005 Is migration of earlier payloads defined? [Completeness, Spec §FR-A06-313] — schema 1 → 2 with Bars and defaults.

## Requirement Clarity

- [x] CHK006 Is "differ" between scene pictures quantified? [Clarity → fixed, Spec §SC-A06-303] — failed first ("probe pixels" undefined); now a 16 × 16 grid with a 16/255 channel threshold.
- [x] CHK007 Is the linearity criterion stated independent of smoothing transients? [Clarity → fixed, Spec §SC-A06-301] — failed first; now "once its smoothing has settled".
- [x] CHK008 Are feature indices for actions fixed? [Clarity, Spec §Clarifications] — level…high = 0…6.
- [x] CHK009 Is the rest value defined? [Clarity, Spec §Clarifications, Key Entities] — range minimum.

## Requirement Consistency

- [x] CHK010 Do the editor's editable fields agree between FR-A06-312 and the clarification? [Consistency] — feature and gain only; FR-A06-301 keeps clamp/attack/release in the mapping type.
- [x] CHK011 Are the parameter names consistent between story 2 and the plan? [Consistency] — height, radius, pulse, spin appear in both.
- [x] CHK012 Is the G-SIGNALTEXTURE re-phasing consistent between spec overrides, out-of-scope and plan D8? [Consistency] — yes.

## Acceptance Criteria Quality

- [x] CHK013 Are mapping validation failures enumerated measurably? [Measurability, Spec §SC-A06-302] — unknown feature, non-finite, gain out of 0…4, version.
- [x] CHK014 Is memory growth bounded numerically? [Measurability, Spec §SC-A06-305] — ≤ 64 KiB over 1,000 blocks.

## Scenario & Edge Case Coverage

- [x] CHK015 Are silence, clamping, low sample rates, scene switch during sound, schema-1 restore and Reduce Motion covered? [Coverage, Spec §Edge Cases] — yes.
- [x] CHK016 Is refusal of a damaged restored mapping specified? [Exception, Spec §User Story 2 AC3] — yes.

## Architecture Ownership & Lifecycle

- [x] CHK017 Is ownership split (mapping in VisualCore, scenes app-local) stated? [Constitution II, Spec §Assumptions] — yes.
- [x] CHK018 Is the graphics context kept with the host for all scenes? [Spec §FR-A06-311] — yes.
- [x] CHK019 Are renderer creation/release and mapper reset tied to lifecycle events? [Plan §Lifecycle] — yes.

## Non-Functional: Privacy, Performance, Accessibility, Release

- [x] CHK020 Is privacy restated? [Spec §FR-A06-330] — yes.
- [x] CHK021 Is real-time safety defined for the audio side? [Spec §FR-A06-320] — yes.
- [x] CHK022 Are accessibility requirements defined for the editor and scenes? [Spec §FR-A06-312, 314, 315] — labels, Reduce Motion, spoken scene.
- [x] CHK023 Are claims and look-alike restrictions stated? [Spec §Negative Requirements] — no ProjectM look-alikes, no health claims.
- [x] CHK024 Are test-duration limits stated? [Spec §SC-A06-306] — < 10 s each.

## Dependencies & Assumptions

- [x] CHK025 Are region groupings and device-campaign profiling stated as assumptions? [Spec §Assumptions] — yes.

## Notes

- Two items failed on first evaluation (CHK006, CHK007); the spec was corrected the same day.
