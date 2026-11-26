# Requirements Quality Checklist: R02-G18-10 device automation preparation

**Purpose**: Unit tests for the requirements of feature 480 (device rows and coverage, scenario set, definition schema,
check and release step, pass conditions, owner steps, no device contact)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26; following feature 470's checklist; every item
passed at first reading.

## Rows and coverage

- [x] CHK001 Is every device row named with its id, title and the earlier tasks it covers? [Completeness, Spec
  §Clarifications Q1]
- [x] CHK002 Is every open {device} task of features 471–479 named and mapped to at least one row? [Coverage, Spec
  §FR-R02G1810-003; Clarifications Q1]
- [x] CHK003 Are the six UA-F13 measurement names stated and mapped to rows? [Completeness, Spec §FR-R02G1810-003]
- [x] CHK004 Is the non-gating row (VoiceOver) identified with its reason? [Clarity, Spec §Clarifications Q1; P-08]

## Scenario set and schema

- [x] CHK005 Is the device scenario set listed by name, with the reason the other scenarios stay simulator-only?
  [Clarity, Spec §Clarifications Q2]
- [x] CHK006 Are the definition's location, schema and every row field defined, including the fixed status value?
  [Completeness, Spec §Clarifications Q3; data-model]

## Check and release step

- [x] CHK007 Are the check's failure cases defined with named reasons (missing scenario, missing field, uncovered task,
  unreadable file, wrong schema, unknown experience)? [Edge Case, Spec §Edge Cases; FR-R02G1810-004]
- [x] CHK008 Is the release step that runs the check named? [Completeness, Spec §Clarifications Q4]
- [x] CHK009 Is it measurable that removals make the check fail (SC-002)? [Measurability, Spec §SC-R02G1810-002]

## Pass conditions and owner steps

- [x] CHK010 Are pass conditions tied to stated budgets or to "recorded" or a stated observation? [Clarity, Spec
  §Clarifications Q5]
- [x] CHK011 Are owner-only device steps listed per row and recorded as BLOCKED_OWNER_ACTION when needed? [Coverage,
  Spec §Edge Cases]

## No device contact

- [x] CHK012 Is it stated that no device is contacted and no device number is claimed before the campaign? [Scope, Spec
  §FR-R02G1810-005; Edge Cases]
- [x] CHK013 Is D3's operating system rule (iPadOS 26.5, never updated) stated? [Consistency, Spec §Edge Cases]

## Scope

- [x] CHK014 Is the player impact stated (every deferred device promise of the game is measured before release, nothing
  improvised on the devices)? [Clarity, Spec §US1]
- [x] CHK015 Is it stated that this feature adds no code, visuals or layout, so code-only graphics, licensing and the
  iPhone and iPad layout stay those of features 473, 476 and 479? [Scope, Spec §Assumptions]
- [x] CHK016 Does the touch-feel row name every gesture of feature 474 (a periapsis-knob drag with the ghost orbit, a
  size-handle drag, an orbiter drag that cranks the shown tick, a double tap on empty space, two-finger orbit) rather
  than another game's gestures? [Consistency, Spec §Clarifications Q1 and facts]

## Notes

- `/speckit-implement` reads these markers and does not change them.
- CHK016 is kept from feature 470's checklist: a ported definition must be read against this game's gestures (the
  lesson of features 440 … 470). It passed at first reading: the AW-D4 answer names the five gestures of feature 474.
