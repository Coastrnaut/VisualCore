# Requirements Quality Checklist: R02-G21-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 506 (player impact, deterministic invariants, empty and error
states, accessibility, sound, iPad and iPhone layout, tier safety, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 496's checklist, after the
items were generated in this skill invocation; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the announcement texts given word for word for a ring, phase, luminosity and tilt change, undo, redo, a
  won run, a failed run, a level or mode change and every refusal code the adapter can return (with the engine's prefix
  read, and a fallback text for codes that cannot arise from the panel)? [Clarity, Spec §Clarifications Q1;
  FR-R02G2106-002]
- [x] CHK002 Is it stated whether a revealed hint, changing the selected star, previews, the shown tick, the view,
  dismissing the tutorial and the Sound toggle are announced? [Coverage, Spec §Clarifications Q1; Edge Cases]
- [x] CHK003 Is the haptic for each outcome stated, including that the run plays only its outcome and that an
  arrangement action never ends the level? [Completeness, Spec §Clarifications Q2; FR-R02G2106-003]
- [x] CHK004 Is "a world keeps its light" defined once and used the same way in the announcements, the summary and the
  ambient recipe? [Consistency, Spec §Clarifications Q1, Q4]

## Deterministic invariants

- [x] CHK005 Is it stated that plans are pure functions of the old and new core and that no feedback, light or sound
  changes state or digest? [Consistency, Spec §FR-R02G2106-004, 009; Clarifications Q1, Q3]
- [x] CHK006 Are the faded elements, their targets and durations, the clock they ease by and the flicker measure
  stated in numbers, including the shown tick stepped back and forth every frame? [Measurability, Spec §Clarifications
  Q3; SC-R02G2106-003]
- [x] CHK007 Do FR-004, the clarification and the plan name the same treatment (glow, each world's shell and the won
  look faded; corona rays and motes held still under Reduce Motion or Reduce Flashing; player-changed elements and the
  won run's motes not faded)? [Consistency, Spec §FR-R02G2106-004; Clarifications Q3; Plan §Research]

## Empty and error states

- [x] CHK008 Are VoiceOver off, sound off, an unavailable audio session, the audition of a star that cannot change and
  bursts of actions defined? [Coverage, Spec §Edge Cases; Clarifications Q4]

## Accessibility and layout

- [x] CHK009 Are the panel's labels, values, the adjustable star, ring, phase, luminosity, tilt and tick elements, the
  locked-control wording and the summary element defined in words? [Completeness, Spec §FR-R02G2106-001;
  Clarifications Q5]
- [x] CHK010 Are Dynamic Type, Increase Contrast, the iPhone scrolling and the iPad width (at most 520 points) stated?
  [Coverage, Spec §FR-R02G2106-005; Clarifications Q5]

## Sound

- [x] CHK011 Are the audition and ambient recipes stated functions (tone by ring, the fifth or a 3 Hz beat, when it
  plays; partials by worlds keeping their light, the brightness partial, at most 6 partials within the shared player's
  limits) with no recorded audio and the toggle off by default? [Clarity, Spec §Clarifications Q4; FR-R02G2106-006]

## Tier safety and changed tests

- [x] CHK012 Is identical behaviour at level-0, level-1, level-2 and the fallback stated measurably, with a tier change
  or memory warning resetting nothing? [Measurability, Spec §FR-R02G2106-007; SC-R02G2106-005; Clarifications Q6]
- [x] CHK013 Are the existing tests that change named, the won-look settling frame included? [Traceability, Spec
  §FR-R02G2106-009]

## Simulator proof

- [x] CHK014 Are the host and simulator proofs stated (scripted plans exact, level 1 won through accessibility actions,
  Reduce Motion and Reduce Flashing frames still between actions, the sound state table, equal logs across tiers)?
  [Measurability, Spec §SC-R02G2106-001 … 005]

## Future D1/D2/D3 evidence

- [x] CHK015 Are sound, haptics and VoiceOver on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G2106-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK007 failed at first reading: the clarification did not cover the pollen motes a won run adds, and did not say how
  a world's shell factor (vertex data of the glow mesh, not a uniform) is eased; the clarification now names both.
  CHK013 failed at first reading: FR-009 named a Reduce Flashing motion assertion that no committed test makes and
  missed `aWonLevelBloomsEveryWorld`; FR-009 now names the true list. Every other item passed at first reading.
