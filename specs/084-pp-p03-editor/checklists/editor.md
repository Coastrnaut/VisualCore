# Editor Requirements Quality Checklist: Physics Playground — Phase 03

**Purpose**: Unit tests for the requirements of A11-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are both Phase 03 gates (spawn, grab, pin and delete gestures; mass-zero static fixture) required with measurable outcomes? [Spec §Canonical overrides, SC-A11-301, 302] — yes.
- [x] CHK002 Is every edit action specified with its values, ranges and refusal codes? [Clarifications Q1, contracts/actions.md] — yes.
- [x] CHK003 Is the gesture-to-action mapping with priorities and the double-tap window specified? [Clarifications Q2] — yes.
- [x] CHK004 Is the grab pull defined (stiffness, damping, not a saved spring) with a measurable target? [Clarifications Q3, SC-A11-303] — yes.

## Architecture ownership

- [x] CHK005 Is it explicit that editing and overlays are app-local over VisualCore's recognizers, arbiter, springs and primitives, with no VisualCore change? [Spec §Canonical overrides, plan] — yes.
- [x] CHK006 Is pinning defined in terms of the solver's existing static path (inverse mass and inertia 0)? [FR-A11-302, research D1] — yes.

## Overlays and truthful claims

- [x] CHK007 Are arrow scales, caps and arrowhead sizes stated, and panel units and precision given? [Clarifications Q4] — yes.
- [x] CHK008 Is it stated which forces are drawn and which are not, and what a restored world shows before its next tick? [Spec §Edge Cases] — failed at first (contact and drag forces and the restored state were unspecified); an Edge Cases bullet now says only weight and net spring force are drawn, the panel says so, and a restored world shows no spring-force arrow until a tick runs.
- [x] CHK009 Are the panel's values labelled as educational approximations? [FR-A11-311] — yes.

## iOS lifecycle and persistence

- [x] CHK010 Are cancelled gestures, a second finger and suspension defined to end a grab? [Spec §Edge Cases, plan Lifecycle] — yes.
- [x] CHK011 Are schema 3, its defaults and the 2 → 3 migration required, with reset clearing edit state? [Clarifications Q5, FR-A11-320] — yes.

## Accessibility

- [x] CHK012 Does every gesture have a native control alternative with labels and values? [FR-A11-303, Clarifications Q2] — yes.

## Edge cases

- [x] CHK013 Are taps on bodies, outside the stage, adds without room, grabbing pinned or static bodies, deleting the grabbed or selected body and fast flicks addressed? [Spec §Edge Cases] — yes.

## Testability and performance

- [x] CHK014 Are the fixtures named and the tolerances (exact 0 displacement, g within 1 %, 5 cm in 1 s, one pixel) stated? [SC-A11-301–306, research D5] — yes.
- [x] CHK015 Are per-event and per-frame work bounds and test durations stated without unmeasured claims? [Plan §Technical Context] — yes.

## Privacy

- [x] CHK016 Are no permission, no network and no stored personal data restated? [Spec §Negative Requirements] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK008 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
