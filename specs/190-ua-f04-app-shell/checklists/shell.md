# App shell Checklist: UA-F04 — The VisualCore app shell

**Purpose**: Unit tests for the UA-F04 requirements: completeness, clarity, consistency, measurability, lifecycle
and failure coverage, privacy and no-advertising constraints, accessibility, the split between
simulator-verifiable and device-only requirements, and traceability to the sources
**Created**: 2026-11-12
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

**Ownership**: reviewer-owned; `[x]` means the reviewer judged the requirement quality sufficient, not that the work
is done. `/speckit-implement` reads these markers and does not change them.

## Requirement Completeness

- [x] CHK001 Are the app target, its two test targets, its identifier and its display name stated? [Completeness, Spec §FR-U04-001]
- [x] CHK002 Is it stated what a release build must not contain? [Completeness, Spec §FR-U04-004]
- [x] CHK003 Is the rule that decides which experiences are shown complete (available and registered)? [Completeness, Spec §FR-U04-011]
- [x] CHK004 Are all parts of a tile listed (identifier, label, tier text, picture)? [Completeness, Spec §FR-U04-021]
- [x] CHK005 Are all four routes and their identifiers named? [Completeness, Spec §FR-U04-030]
- [x] CHK006 Are all settings listed with what each keeps? [Completeness, Spec §FR-U04-050–054]
- [x] CHK007 Is every item of the shell's preferences listed? [Completeness, Spec §FR-U04-060]
- [x] CHK008 Is the question of an app icon answered? [Gap, Spec §FR-U04-006]

## Requirement Clarity

- [x] CHK009 Is "tier as text" given as exact words? [Clarity, Spec §FR-U04-021]
- [x] CHK010 Is the range of the quality override stated, and what happens to a tier an experience lacks? [Ambiguity, Spec §FR-U04-051]
- [x] CHK011 Is "catalog filter" defined? [Ambiguity, Spec §FR-U04-033]
- [x] CHK012 Is the length of a search text bounded? [Gap, Spec §FR-U04-022]
- [x] CHK013 Is "regular" and "compact" layout tied to observable behavior? [Clarity, Spec §FR-U04-032]
- [x] CHK014 Is it exact what each reset removes? [Clarity, Spec §FR-U04-052]

## Requirement Consistency

- [x] CHK015 Do the first-run requirements agree with the fact that no experience is available yet? [Consistency, Spec §FR-U04-041, Assumptions]
- [x] CHK016 Do the premium requirements stay clear of the purchase feature? [Consistency, Spec §FR-U04-012, FR-U04-072]
- [x] CHK017 Do the count of route checks and the device and text-size matrix agree? [Consistency, Spec §SC-U04-004, FR-U04-080]

## Acceptance Criteria Quality

- [x] CHK018 Does every acceptance item of the brief have a requirement and a success criterion? [Traceability, Spec §Traceability]
- [x] CHK019 Are all success criteria stated with counts? [Measurability, Spec §SC-U04-001–010]
- [x] CHK020 Is "no clipped control" something a test can decide? [Measurability, Spec §FR-U04-035, SC-U04-004]

## Lifecycle and Failure Coverage

- [x] CHK021 Are a damaged catalog and unreadable preferences covered without a crash? [Coverage, Spec §FR-U04-024, FR-U04-060]
- [x] CHK022 Is the empty launcher covered as a real state? [Coverage, Spec §FR-U04-023]
- [x] CHK023 Is a registry mismatch covered? [Coverage, Spec §FR-U04-011]
- [x] CHK024 Are failure, cancellation, backgrounding and memory messages of an open experience covered in the route? [Coverage, Spec §Edge Cases, FR-U04-031]
- [x] CHK025 Is restoring to an experience that is no longer available covered? [Edge Case, Spec §FR-U04-033]
- [x] CHK026 Is a reset while an experience is open covered? [Edge Case, Spec §FR-U04-052]

## Privacy, Advertising, Accessibility, Devices

- [x] CHK027 Are no network, no advertising, no account, no URL scheme and no usage description requirements? [Completeness, Spec §FR-U04-034, FR-U04-070, FR-U04-071]
- [x] CHK028 Is the content of the privacy statement specified? [Completeness, Spec §FR-U04-053]
- [x] CHK029 Are identifiers, text size, touch target size and colour independence required? [Completeness, Spec §FR-U04-021, FR-U04-035]
- [x] CHK030 Are the device-only and the owner-only item named and kept out of the agent's work? [Completeness, Spec §FR-U04-083, FR-U04-084]
- [x] CHK031 Is it required that test support is absent from release builds, with a proof? [Measurability, Spec §FR-U04-081, SC-U04-008]

## Traceability

- [x] CHK032 Does every functional requirement appear in the traceability table? [Traceability, Spec §Traceability]
- [x] CHK033 Is every unique requirement of R02-F25 and R02-F26 listed with a decision and a reason? [Traceability, Spec §Absorbed source requirements]

## Notes

- Items are evaluated by the reviewer (the agent acting under the owner's standing delegation).
- Review 2026-11-12: four items failed against the specification as it stood after `/speckit-plan` and were
  corrected in spec.md before they were marked:
  - CHK008: FR-U04-006 now states that no icon or raster is added here.
  - CHK010: FR-U04-051 now gives the range 0 to 7 and the rule for a tier an experience lacks.
  - CHK011: FR-U04-033 now defines the catalog filter as the search text.
  - CHK012: FR-U04-022 now bounds the search text at 100 characters.
- All 33 items pass after the corrections. The specification now has 39 functional requirements.
