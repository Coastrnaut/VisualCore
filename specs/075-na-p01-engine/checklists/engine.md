# Engine Requirements Quality Checklist: Neon Arcade — Phase 01

**Purpose**: Unit tests for the requirements of A10-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK007).

## Completeness

- [x] CHK001 Are the manual's Phase 01 gates (one complete Neon Dodge game; recorded replay gives identical score and collision ticks; context ownership in the host) all required with acceptance scenarios? [Spec §US1, §US2, FR-A10-110–112, 120] — yes.
- [x] CHK002 Are all fields of the game run, player, falling objects, events and catalog items defined with ranges? [Spec §Key Entities; data-model.md] — yes.
- [x] CHK003 Are the catalog refusal reasons enumerated? [Clarifications Q5, FR-A10-113] — yes (four named reasons).
- [x] CHK004 Are the generic collision operations and their touching/non-finite semantics specified? [Spec §US3, FR-A10-101, Clarifications Q2] — yes.

## Clarity and measurability

- [x] CHK005 Are field size, units, step, speeds and spawn schedule quantified? [Clarifications Q1, Q3] — yes (9 × 16, 1/60 s, 9 units/s, first spawn step 30 then every 40, fall 3–5 units/s).
- [x] CHK006 Is "replay identical" measurable (what is compared, at which frame times)? [Spec §SC-A10-102, research D4] — yes (score, lives, events; 1/30, 1/60, 1/120 s).
- [x] CHK007 Is the outcome of every player–object contact defined, including contact during invulnerability? [Spec §US1 AC3–4, Edge Cases] — failed at first (a hazard touching during invulnerability was undefined); an Edge Cases bullet now says it passes without effect, and restart values are stated.
- [x] CHK008 Is "cannot tunnel" quantified for both circle and capsule objects? [Spec §SC-A10-103, Clarifications Q2, research D3] — yes (swept for circles at 4–50× summed radii; capsule speed bound 0.083 < 0.6 per step).

## Architecture ownership

- [x] CHK009 Is it stated which pieces go to VisualCore (generic overlap and swept tests) and which stay app-local (rules, spawning, scoring, content), and what A10-P02 takes over? [Spec overrides, FR-A10-101, 110, Assumptions] — yes.
- [x] CHK010 Is the VisualCore change's documentation, interface record and reference-regression timing required? [Spec §FR-A10-103] — yes (docs and API baseline here; regression at X-A10 by owner ruling).

## iOS lifecycle and recovery

- [x] CHK011 Is "no catch-up after suspension" specified with its mechanism? [Spec §US4 AC2, FR-A10-121, plan Lifecycle] — yes.
- [x] CHK012 Is the behaviour for damaged or newer saved state specified? [Spec §US4 AC3] — yes (refused; a new run opens).

## Accessibility and privacy

- [x] CHK013 Are control labels, a spoken game state and Reduce Motion behaviour required with a measure? [Spec §FR-A10-120, 122] — yes (labels and values; spoken score, lives, state; drawn pulse and drift halved, game unchanged).
- [x] CHK014 Is the absence of permissions, network, leaderboards and monetization stated? [Spec §Negative Requirements] — yes.

## Release constraints and licenses

- [x] CHK015 Is the license rule measurable (allowed list, author, generated document checked against the catalog)? [Clarifications Q5, FR-A10-113, SC-A10-104] — yes.
- [x] CHK016 Are skill, reflex, cognitive and health claims excluded? [Spec §Negative Requirements] — yes.

## Testability and performance

- [x] CHK017 Is every success criterion tied to a runnable check with test time bounds? [SC-A10-101–106, quickstart] — yes.
- [x] CHK018 Are per-step and per-frame loads bounded without performance claims? [Clarifications Q3, plan Performance] — yes (≤ 24 objects, ≤ 256 events, ≤ 30 shapes plus field and HUD; no fps claim).

## Notes

- 18 items evaluated on 2026-11-14; CHK007 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
