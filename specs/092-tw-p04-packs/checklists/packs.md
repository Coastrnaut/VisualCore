# Packs Requirements Quality Checklist: Tiny Worlds — Phase 04

**Purpose**: Unit tests for the requirements of A12-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK010).

## Completeness

- [x] CHK001 Are both manual phase gates (prop placement and light in each pack; camera limits without clipping) mapped to requirements? [Spec §Traceability, FR-A12-401, 404] — yes.
- [x] CHK002 Is each pack's content specified (seed, prop counts by kind, light, camera ranges, default view)? [Clarifications Q2] — yes.
- [x] CHK003 Is the opening and reset behaviour specified, including Reduce Motion and speech? [FR-A12-402, Clarifications Q1] — yes.

## Architecture ownership

- [x] CHK004 Is it stated that packs are data over the existing rules with no VisualCore change? [plan Summary, Assumptions] — yes.
- [x] CHK005 Is the decision not to change the state schema justified (one pack per preset)? [Clarifications Q1] — yes.

## Rules, limits and clearance

- [x] CHK006 Are the per-pack camera ranges stated to lie within the global ones? [FR-A12-404, Clarifications Q2–Q3] — yes.
- [x] CHK007 Is the prop-aware clearance defined precisely (which props, which height, which radius)? [Clarifications Q3] — yes.
- [x] CHK008 Is the refusal of a pack whose props break the rules defined, with the refusal code? [FR-A12-403, Clarifications Q5] — yes.

## Data and recovery

- [x] CHK009 Are the fixtures (digest after opening, reset equality, broken pack) defined measurably? [Clarifications Q5, SC-A12-401, 403] — yes.
- [x] CHK010 Is the effect of the new per-preset limits on saved worlds and restored states defined? [Edge Cases] — failed at first (not stated); corrected: views are clamped on restore, props and light kept.

## Interface and accessibility

- [x] CHK011 Does every pack action have a control and spoken feedback? [FR-A12-402, plan Project Structure] — yes.

## Privacy

- [x] CHK012 Is all pack content bundled, original and licensed, with no network or permission? [FR-A12-406, Negative Requirements] — yes.

## Performance and budgets

- [x] CHK013 Are the per-pack budgets quantified (props, vertices, draws)? [Clarifications Q4, SC-A12-404] — yes.
- [x] CHK014 Are performance claims excluded beyond those budgets? [Spec §Success Criteria] — yes.

## Testability and release

- [x] CHK015 Is the camera sweep size stated? [SC-A12-402] — yes (24 × 8 × 4 per pack).
- [x] CHK016 Is the experience kept a candidate and every Spec Kit step required? [Spec §Canonical overrides] — yes.

## Notes

- 16 items evaluated on 2026-11-15; CHK010 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
