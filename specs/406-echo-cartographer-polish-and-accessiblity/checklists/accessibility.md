# Requirements Quality Checklist: R02-G11-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 406 (player impact, deterministic invariants, empty and error
states, accessibility, licence, layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23, following feature 396's checklist; failures
were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the announcement texts given word for word for a pulse, a located beacon, a missed claim, a marker, undo,
  redo, win, failure, level change and every refusal code the adapter can return? [Clarity, Spec §Clarifications Q1;
  FR-R02G1106-002]
- [x] CHK002 Is it stated whether a revealed hint, cursor moves and orbit are announced? [Coverage, Spec §Clarifications
  Q1; Edge Cases]
- [x] CHK003 Is the haptic for each outcome stated, including which one wins when an action also ends the play?
  [Completeness, Spec §Clarifications Q2]

## Deterministic invariants

- [x] CHK004 Is it stated that plans are pure functions of the old and new core and that no feedback, light or sound
  changes state or digest? [Consistency, Spec §FR-R02G1106-007; Clarifications Q1, Q3]
- [x] CHK005 Are the faded elements, their targets and durations, and the flicker measure stated in numbers?
  [Measurability, Spec §Clarifications Q3; SC-R02G1106-003]
- [x] CHK006 Do FR-004, the key entities and User Story 2 name the same treatment as the clarification (glow and won
  brightening faded; rings and flares at rest under Reduce Flashing; player-revealed elements not faded)? [Consistency,
  Spec §FR-R02G1106-004; US2] — corrected 2026-11-23: User Story 2's acceptance scenario promised that every brightness
  change fades, which contradicts the clarified treatment of rays, walls and tiles.
- [x] CHK007 Are the ring and flare rates stated against the 3-per-second limit, including why they restart on undo and
  redo? [Measurability, Spec §Clarifications Q3; Research R2, R5]

## Empty and error states

- [x] CHK008 Are VoiceOver off, sound off, an unavailable audio session and bursts of actions defined? [Coverage, Spec
  §Edge Cases]

## Accessibility

- [x] CHK009 Are the panel's labels, values, adjustable column and row and summary element defined in words?
  [Completeness, Spec §FR-R02G1106-001; Clarifications Q5]
- [x] CHK010 Are Dynamic Type, Increase Contrast and the iPad width stated? [Coverage, Spec §FR-R02G1106-005;
  Clarifications Q5]

## Licence and sound

- [x] CHK011 Is the sound recipe a stated function (root by energy share, partials by located beacons, stage changes,
  whole-cycle loop) with no recorded audio? [Clarity, Spec §Clarifications Q4; Assumptions]

## Simulator proof

- [x] CHK012 Are the host and simulator proofs stated (scripted plans exact, level 1 won through accessibility actions,
  Reduce Motion frames identical, no ring or flare under Reduce Flashing, the loop's state table)? [Measurability, Spec
  §SC-R02G1106-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK013 Are sound, haptics and VoiceOver on hardware tagged `{device}` and deferred to after
  ImplementationLock-100? [Completeness, Spec §SC-R02G1106-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK006 failed at first reading; the spec was corrected before the items were judged.
