# Requirements Quality Checklist: R02-G20-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 496 (player impact, deterministic invariants, empty and error
states, accessibility, licence and sound, iPad and iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 486's checklist, after the
items were generated in this skill invocation; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the announcement texts given word for word for a pod placement, move and removal, a vent change, a
  moonlight change, undo, redo, a won run, a failed run, a level change and every refusal code the adapter can return
  (with the engine's prefix read, and a fallback text for the codes that cannot arise from the panel)? [Clarity, Spec
  §Clarifications Q1; FR-R02G2006-002]
- [x] CHK002 Is it stated whether a revealed hint, changing the panel's selection, drag previews, the shown cycle, the
  view, dismissing the tutorial and the Sound toggle are announced? [Coverage, Spec §Clarifications Q1; Edge Cases]
- [x] CHK003 Is the haptic for each outcome stated, including that the run (which always ends the level) plays only its
  outcome and that a pod, vent or moonlight action never ends the level? [Completeness, Spec §Clarifications Q2]
- [x] CHK004 Is "colonies staying in band" defined once and used the same way in the announcements, the summary and the
  ambient recipe? [Consistency, Spec §Clarifications Q1, Q4]

## Deterministic invariants

- [x] CHK005 Is it stated that plans are pure functions of the old and new core and that no feedback, light or sound
  changes state or digest? [Consistency, Spec §FR-R02G2006-007; Clarifications Q1, Q3]
- [x] CHK006 Are the faded elements, their targets and durations, the clock they ease by (the frame clock, so fades
  finish under Reduce Motion) and the flicker measure stated in numbers? [Measurability, Spec §Clarifications Q3;
  SC-R02G2006-003]
- [x] CHK007 Do FR-004, User Story 2, the clarification and research R3 name the same treatment (glow and won look
  faded; droplets and motes held still under Reduce Motion or Reduce Flashing and under 1 cycle per second otherwise;
  player-changed elements not faded)? [Consistency, Spec §FR-R02G2006-004; US2; Clarifications Q3; Plan §Research R3]

## Empty and error states

- [x] CHK008 Are VoiceOver off, sound off, an unavailable audio session, the audition of a site that cannot take a pod
  and bursts of actions defined? [Coverage, Spec §Edge Cases; Clarifications Q4]

## Accessibility and layout

- [x] CHK009 Are the panel's labels, values, adjustable slot, site and moonlight, the vent toggles' values and the summary
  element defined in words? [Completeness, Spec §FR-R02G2006-001; Clarifications Q5]
- [x] CHK010 Are Dynamic Type, Increase Contrast, the iPhone scrolling and the iPad width stated? [Coverage, Spec
  §FR-R02G2006-005; Clarifications Q5]

## Licence and sound

- [x] CHK011 Are the audition and ambient recipes stated functions (the tone by site a whole tone apart, the fifth or a
  3 Hz beat, decay, when it plays; root by actions share, partials by quarters of the colonies staying in band, the
  moonlight partial, stage changes, whole-cycle loop) with no recorded audio? [Clarity, Spec §Clarifications Q4; FR-006;
  Assumptions]

## Simulator proof

- [x] CHK012 Are the host and simulator proofs stated (scripted plans exact, level 1 won through accessibility actions —
  its witness is a pod and a vent, both reachable through the adjustables, Place and the vent toggle — Reduce Motion and
  Reduce Flashing frames identical, the sound state table)? [Measurability, Spec §SC-R02G2006-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK013 Are sound, haptics and VoiceOver on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G2006-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK007 was read twice: unlike feature 486 the forest has a time input (droplets and motes), so the clarification holds
  their time at 0 under either comfort setting; the item passes. Every other item passed at first reading.
