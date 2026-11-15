# Feature Specification: Neon Arcade — Phase 05 Balance, device QA and storefront

**Feature Branch**: `079-na-p05-balance` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A10-P05 (legacy ledger) · ID namespace FR-A10-5##, SC-A10-5##, T-A10-5##

**Input**: User description: archived manual `apps/10-neon-arcade.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — particles, glow and visual feedback constrained by game readability;
  regression fixture — hitboxes remain readable when the glow quality changes; graphics-context ownership stays solely
  in the VisualCore host.
- **Gap built here** (contract `docs/apps/neon-arcade/visualcore-contract.json`): G-GLOWCAPS (app-local) — glow and
  particle budgets per quality level within stated caps, a glow that never hides a collision shape, reduced flashing
  removing glow pulses.
- **Quality levels** are declared here: the experience's declared level count matches the levels the drawing uses and
  its catalog registration.
- **Balance**: the difficulty and scoring values of A10-P02 are checked against measurable targets with simulated
  players; values change only where a target is missed (recorded).
- **Device QA**: device measurements (frame pacing, thermals, glow readability on a real screen, audio routes) are
  planned in a device-campaign document; device tasks are tagged {device} and run only after ImplementationLock-100.
- **Storefront**: there is no per-app store listing (ADR-0009); the experience's catalog entry (name, short
  description, palette, capabilities) is its storefront inside the one app and is written truthfully here.
- **Owner rulings:** short tests; iOS 27 at phase gates; reference regression and iOS 26 at X-A10; every Spec Kit step
  runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
Neon Arcade declares one quality tier (`qualityTiers` 1, registration `["level-0"]`); its presenter draws each object's
glow at 1.6 × the radius with an alpha pulse (amplitude 0.15, halved under Reduce Motion) and keeps one particle pool of
256; Digital Aquarium declares three levels in `AquariumBudget.levels` (level 0 first, the lowest) and injects Low
Power Mode into its presenter (`lowPowerMode`, default `ProcessInfo.isLowPowerModeEnabled`); the host passes the
governor's tier to `draw(_:tier:context:frame:)`.

- Q: Which quality levels exist and what are their caps? → A: Three levels, `level-0` (lowest) … `level-2` (full),
  declared by the core (`qualityTiers` 3), the presenter and the registration: level 2 — glow 1.6 × radius, glow
  opacity ≤ 0.35 including the pulse, ≤ 256 live particles; level 1 — 1.4 ×, ≤ 0.30, ≤ 128; level 0 — 1.2 ×, ≤ 0.25
  and no pulse, ≤ 48. Bursts scale their particle counts by the level's cap ÷ 256 (at least 1). Low Power Mode selects
  level 0; reduced flashing removes the pulse at every level.
- Q: How is "readable" measured? → A: By colour contrast ratios (the relative-luminance ratio used by WCAG): a
  hazard's core against the field ≥ 4.5 : 1, and against its own glow composited over the field at the level's
  maximum opacity ≥ 3 : 1; the player and orbs likewise ≥ 3 : 1 against the field; collision shapes are drawn above
  every glow and particle at their rule sizes. Colours are tuned in the catalog if a ratio is missed (recorded).
- Q: Who are the simulated players and what are the targets? → A: Deterministic test players that send only
  `run.steer` actions: *idle* (always 0); *dodger* (steers away from the nearest hazard less than 4 units above the
  player within 1 unit sideways, else back toward the centre lane); *collector* (as the dodger, but with no hazard
  threat it steers toward the nearest orb). Targets over 20 seeds, at most 6,000 steps each: idle median wave ≤ 2;
  dodger median wave ≥ 3; collector median score > dodger median score > idle median score. These measure the game's
  curve, not anyone's ability. Missed targets are tuned in the difficulty or spawn values and recorded.
- Q: What does the device-campaign document hold? → A: `docs/apps/neon-arcade/device-campaign.md` modelled on Digital
  Aquarium's: rows for frame pacing per level on the reference phone and tablet, thermal state over a 10-minute session
  (at the campaign), glow readability on a real screen in bright light, audio route changes (headphones, silent
  switch), VoiceOver pass, each with device, procedure, threshold and status "pending device campaign" until
  ImplementationLock-100; the matching tasks are tagged {device}.
- Q: What does the catalog entry say? → A: Name "Neon Arcade", a one-line description "Neon Dodge: steer through
  falling hazards and collect orbs in waves." and capabilities that are each proved by a named test (fixed-step game,
  swept collision, wave patterns, local high scores, synthesized sounds and haptics, five steering sensitivities,
  quality levels); `scripts/check_distinctiveness.py` and a realism-word scan reject benefit claims.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Glow that never hides the danger (Priority: P1) 🎯

Whatever the device's quality level, the glow around hazards, orbs and the player stays within limits: every
collision shape is drawn at its rule size above its glow with a clear contrast, and lowering the quality reduces glow
and particles without changing the game.

**Why this priority**: the manual's Phase 05 MVP and regression fixture; manual risk 1 ("effects that obscure obstacles
hurt playability"); gap G-GLOWCAPS.

**Independent Test**: for each quality level, the glow size, glow opacity and particle counts are within that level's
caps; every hazard's core colour has at least the stated contrast against its own glow and the field; the game digest
is identical at every level.

**Acceptance Scenarios**:

1. **Given** each quality level, **When** a frame with hazards, orbs, the player and effects is drawn, **Then** glow
   radius, glow opacity and live particles stay within that level's caps.
2. **Given** the quality level changes during a run, **When** the next frames are drawn, **Then** every collision shape
   keeps its size and position and the game state is unchanged.
3. **Given** reduced flashing, **When** glow would pulse, **Then** it stays steady.

---

### User Story 2 - A fair difficulty curve (Priority: P1)

The game starts gentle and ramps up: a careful player can reach several waves, an idle player loses quickly, and a
player who collects orbs scores clearly more than one who only dodges.

**Why this priority**: manual risk 2 (frame-rate-dependent or unfair difficulty) and the phase's "balance" deliverable.

**Acceptance Scenarios**:

1. **Given** simulated players (idle, a simple dodger, a dodger that also collects), **When** each plays from 20 seeds,
   **Then** their median waves and scores meet the stated targets and are ordered idle < dodger < collector by score.
2. **Given** the same seeds at 1/30 and 1/60 s frame pacing, **When** the simulated players play, **Then** the results
   are identical.

---

### User Story 3 - Ready for the device campaign and truthfully described (Priority: P2)

The owner has a written plan of what to measure on the phone and the tablet before release, and the catalog entry
describes Neon Arcade exactly as it is.

**Acceptance Scenarios**:

1. **Given** the device-campaign document, **When** it is read, **Then** each measurement names the device, the
   procedure, the pass threshold and that it waits for ImplementationLock-100.
2. **Given** the catalog entry, **When** it is checked, **Then** every capability it names is proved by a test and no
   skill, reflex, cognitive or health benefit is claimed.

### Edge Cases

- **The quality level drops mid-burst:** particles above the new cap are removed oldest first; no new burst exceeds it.
- **Low Power Mode and the host's level:** the level drawn is 0 while Low Power Mode is on, otherwise the host's chosen
  level clamped to 0…2 (presentation only; the game never sees it).
- **A simulated player reaches the difficulty ceiling:** the targets account for the capped speed.
- **A balance target fails:** the value is tuned and the change recorded in research; earlier replays and fixtures are
  regenerated.
- **A device not yet tested:** its rows stay "pending device campaign", never "pass".

## Requirements *(mandatory)*

### Functional Requirements

**Glow caps and quality levels (G-GLOWCAPS)**

- **FR-A10-501**: The experience MUST declare a fixed number of quality levels, the same in its core, its drawing and
  its catalog registration, each with caps for glow radius, glow opacity and live particles.
- **FR-A10-502**: Every collision shape MUST be drawn at its rule size above its glow, with a stated minimum contrast
  between a hazard's core and its glow and between the core and the field, at every level.
- **FR-A10-503**: Changing the level MUST NOT change the game state; reduced flashing MUST hold the glow steady; Low
  Power Mode MUST select the lowest level.

**Balance**

- **FR-A10-510**: Simulated players (idle, dodger, collector) MUST meet stated targets for median waves and scores over
  20 seeds and keep the order idle < dodger < collector by median score; results MUST be identical at 1/30 and 1/60 s
  pacing.

**Device QA and storefront**

- **FR-A10-520**: A device-campaign document MUST list each device measurement with device, procedure, threshold and
  status pending until ImplementationLock-100.
- **FR-A10-521**: The catalog entry MUST describe only proved capabilities and make no benefit claims.
- **FR-A10-522**: The scenario manifest MUST add fixtures for each quality level and a level change mid-run.

### Key Entities

- **Quality level**: index, glow radius factor, glow opacity, particle cap, pulse on/off.
- **Simulated player**: kind, steering rule.
- **Balance target**: player kind, metric, threshold.
- **Device measurement**: device, procedure, threshold, status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A10-501**: At every level, 100 % of drawn frames in the tests keep glow and particles within caps and all
  collision shapes at rule size; digests are identical across levels.
- **SC-A10-502**: Contrast between hazard core and glow and between core and field is at least the stated minimum at
  every level.
- **SC-A10-503**: The balance targets are met and ordered over 20 seeds; results identical at two frame pacings.
- **SC-A10-504**: The device-campaign document and the catalog entry pass their checks; 0 benefit claims.
- **SC-A10-505**: The nine standard scenarios and the fixtures pass on iOS 27; each package test finishes in under 10
  seconds.

## Assumptions

- Cap values, contrast thresholds, balance targets and the simulated players' rules are set in clarification; balance
  targets are about the game's own consistency, not about people's abilities.
- Release dossier, privacy document and final verification are A10-P06.

## Out of Scope

- A per-app store listing, screenshots, pricing; measuring on devices before ImplementationLock-100; new game content.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 05 (particles, glow and feedback constrained by readability) — Phase 05 MVP | FR-A10-501–503; story 1 |
| Phase 05 regression fixture "hitboxes remain readable when bloom quality settings change"; manual §11 fixture 5 | FR-A10-502, 503, 522 |
| Manual risks 1 (effects obscuring obstacles) and 2 (difficulty) | FR-A10-502, 510 |
| Manual §12 profiling plan and device separation | FR-A10-520 |
| Contract gap G-GLOWCAPS | FR-A10-501–503 |
| Constitution A10: readability over effects; truthful claims; bounded resources | FR-A10-502, 521, 501 |

## Negative Requirements

- No performance or battery numbers without device measurements; no skill, reflex, cognitive or health claims; no
  per-app store listing; drawing never changes the game; no second renderer or context; no ProjectM code.
