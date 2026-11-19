# Requirements Quality Checklist: R02-F10 spectral colour and non-colour clues

**Purpose**: Unit tests for the requirements of feature 210 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player benefit of every requirement traceable to a user story (readable without colour, colours
  apart, stable hue and contrast, one setting)? [Completeness, Spec §User Stories 1–4]
- [x] CHK002 Is it stated that no rule may depend on colour alone, and how that is enforced for a set of states?
  [Clarity, Spec §FR-R02F10-007]
- [x] CHK003 Is the spoken form of a clue defined (its name), so VoiceOver users get the same information? [Coverage,
  Spec §FR-R02F10-008]

## Deterministic invariants

- [x] CHK004 Are round-trip, hue-rotation and grey-preservation invariants quantified (1e-9, 1e-12)? [Measurability,
  Spec §SC-R02F10-001, 002]
- [x] CHK005 Is the gamut rule specified exactly (chroma bisection, 24 steps, constant lightness and hue) rather than
  "clipped"? [Clarity, Spec §FR-R02F10-002]
- [x] CHK006 Is the separation threshold a number with its conditions (ΔE_OK ≥ 0.08 under all five)? [Clarity, Spec
  §FR-R02F10-005]
- [x] CHK007 Is the seed convention of fixtures stated and kept out of the pure model? [Consistency, Plan §Technical
  Context]

## Empty and error states

- [x] CHK008 Are empty and single-state sets, too many states, repeated ids or names, empty names and non-finite or
  out-of-range components each given an outcome? [Coverage, Spec §Edge Cases]
- [x] CHK009 Does every refusal have a stable reason code that names the feature? [Completeness, Spec §FR-R02F10-011]
- [x] CHK010 Are older and unknown stored preference values given a defined outcome? [Edge Case, Spec §FR-R02F10-010]

## Source licence and code-only graphics

- [x] CHK011 Are the external constants (OKLab, Machado 2009) required to be cited with licences, and the presets and
  shapes required to be original? [Completeness, Spec §FR-R02F10-014] — corrected: FR-R02F10-014 added.
- [x] CHK012 Is it required that shapes and patterns are drawn in code on the existing renderer with no image, font or
  icon asset? [Consistency, Spec §FR-R02F10-008, Negative Requirements]

## iPad/iPhone layout

- [x] CHK013 Are Dynamic Type scaling and compact/regular width requirements stated for the badge and the picker?
  [Gap → Spec §FR-R02F10-013] — corrected: FR-R02F10-013 added.
- [x] CHK014 Is a non-text contrast requirement stated for a clue against its colour and background? [Gap → Spec
  §FR-R02F10-013] — corrected.

## Simulator proof

- [x] CHK015 Are shader–CPU parity tolerances and both simulator runtimes named? [Measurability, Spec §SC-R02F10-004]
- [x] CHK016 Is it stated that existing palette, colour, state-sign and preference tests stay unchanged and the reference
  regression passes 7 of 7? [Consistency, Spec §SC-R02F10-006]

## Future D1/D2/D3 evidence

- [x] CHK017 Are the device-only items named concretely (presets and badges on D1–D3 in light and dark) and deferred to
  after ImplementationLock-100, with no simulator result claimed as device evidence? [Completeness, Spec §Canonical
  overrides] — corrected: the device-only line was made concrete.

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
