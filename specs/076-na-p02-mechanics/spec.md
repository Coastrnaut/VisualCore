# Feature Specification: Neon Arcade — Phase 02 Neon Dodge complete mechanics

**Feature Branch**: `076-na-p02-mechanics` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A10-P02 (legacy ledger) · ID namespace FR-A10-2##, SC-A10-2##, T-A10-2##

**Input**: User description: archived manual `apps/10-neon-arcade.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — deterministic fixed-step update loop and authoritative collision rules,
  now with the complete Neon Dodge mechanics; regression fixture — background/resume freezes the simulation rather
  than catching up; graphics-context ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/neon-arcade/visualcore-contract.json`): the rest of G-GAMERULES (app-local):
  lanes, a wave director with data-defined spawn patterns, a difficulty ramp and the scoring that goes with them.
  No VisualCore change is planned (the fixed-step clock, seeded generator and `Collision2D` are reused).
- **Experience:** the candidate `a10.neon-arcade` of A10-P01 is extended; the saved state moves to a new schema with a
  migration of the Phase 01 schema.
- **Owner rulings:** short tests; iOS 27 at phase gates; reference regression and iOS 26 at X-A10; every Spec Kit step
  runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`ArcadeCore` snapshot schema 1 is `ArcadeState` with `MigrationChain(currentVersion: 1)`; Digital Aquarium migrates
older snapshots with `MigrationChain` steps and stores `schemaOneExample()` payloads (`MigrationExample`) that the
registry's migration check restores; `GameSimulation` spawns one random object at step 30 and every 40 steps with fall
speed 3…5 units/s; the capsule speed bound (fall ≤ 5 units/s, 0.083 units per step < 0.6) is a Phase 01 test.

- Q: How many lanes are there, where, and how long is a wave? → A: Five lanes with centres x = 0.9, 2.7, 4.5, 6.3, 8.1
  (1.8 units apart); a wave lasts 600 steps (10 s); wave 1 starts at step 0 and its first spawn comes at wave step 30;
  the player still moves freely across the field (lanes place objects, not the player).
- Q: Which patterns exist and how are they chosen? → A: A pattern table in the experience's core (data with id, name,
  rule, parameters, author "VisualCore project", license "MIT"): `rain` (one object per spawn gap in a seeded lane,
  hazard 70 % / orb 30 %), `wall` (a row every 120 steps: spike-balls of radius 0.5 in four lanes, the free lane seeded,
  never the same free lane twice in a row), `zigzag` (a hazard per spawn gap walking lanes 0→4→0), `orb-trail` (orbs
  per spawn gap in one seeded lane, bars in both neighbouring lanes every second gap). Wave 1 is always `rain`; each
  later wave draws uniformly from the patterns other than the previous wave's.
- Q: How does difficulty rise and where is the ceiling? → A: Level L = min(wave − 1, 8). Fall speed range
  (3 + 0.2 L) … min(5, 3.6 + 0.2 L) units/s (wave 9 on: 4.6…5.0, keeping the capsule bound); spawn gap
  max(20, 40 − 2.5 L) steps; orb multiplier 1 + L / 2 (integer division: 1…5). Survival: 1 point per 60 steps of play.
  A wall row falls 15 units at ≤ 5 units/s (≥ 3 s), while the player crosses at most 7.2 units in under 1 s, so every
  gap is reachable; a test checks it from the values.
- Q: What does the saved state hold, and how is the Phase 01 state migrated? → A: `GameRun` schema 2 adds `wave`
  (≥ 1), `waveStep` (0…599), `patternId`, `freeLane` (the last wall's free lane, −1 for none) and `patternCursor` (the
  zigzag position or the trail lane); `ArcadeState` snapshot schema 2 with `MigrationChain(currentVersion: 2)`, step
  1 → 2 setting wave 1, wave step 0, pattern `rain`, no free lane, cursor 0 and keeping everything else; a stored
  schema-1 example is registered for the migration check.
- Q: What does the person see and hear of the waves? → A: Five dim lane guides drawn as thin lines at the lane centres
  below the HUD, the wave number as drawn digits beside the score, and the spoken description adds "wave n"; the
  pattern table appears in `docs/apps/neon-arcade/content-licenses.md` with role `pattern`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Waves that ask for skill (Priority: P1) 🎯

A person playing Neon Dodge meets hazards and orbs that arrive in lanes and in recognisable waves — a rain of single
objects, a wall with one gap, a zigzag, a trail of orbs guarded by hazards — and each new wave is a little faster and
denser than the last, until a ceiling.

**Why this priority**: version 0.1 feature 01 complete ("player lane, falling hazards and collectible orbs") and the
manual's Phase 02 MVP; the Phase 01 slice only spawned single random objects.

**Independent Test**: from a seed, the run passes through several waves; every spawned object starts at a lane centre;
each wave follows one named pattern; the fall speed and the spawn density of wave n+1 are at least those of wave n and
never exceed the ceiling.

**Acceptance Scenarios**:

1. **Given** a new run, **When** it starts, **Then** wave 1 begins and its pattern is one of the defined patterns.
2. **Given** a wave that has run its length, **When** the next step comes, **Then** the wave number rises by one and a
   pattern is chosen for it from the seeded generator.
3. **Given** a "wall" wave, **When** its row spawns, **Then** hazards fill every lane but exactly one, and the player can
   pass through the gap at the player's maximum speed from any lane in the time the row takes to fall.
4. **Given** any wave, **When** objects spawn, **Then** their fall speed and the gap between spawns follow the difficulty
   of that wave and stay within the ceiling.

---

### User Story 2 - A score that rewards staying alive and collecting (Priority: P1)

The score rises steadily while the person survives and more for each orb, with orbs worth more in later waves, so a
longer, cleaner run scores higher.

**Why this priority**: start/pause/restart/game-over flows with scores (version 0.1 feature 03) need a meaningful score
before local high scores arrive in A10-P04.

**Acceptance Scenarios**:

1. **Given** a run, **When** a full second of play passes, **Then** the score rises by the survival points.
2. **Given** an orb collected in wave n, **When** it is counted, **Then** it adds its value times the wave's multiplier.
3. **Given** a paused or finished run, **When** time passes, **Then** the score does not change.

---

### User Story 3 - Leaving and returning never changes the game (Priority: P1)

Whatever happens while the app is in the background — any length of time — the game continues exactly where it was,
in the same wave at the same step, and a game saved by the Phase 01 version still opens.

**Why this priority**: the manual's Phase 02 regression fixture ("background/resume freezes simulation rather than
catching up") and safe restore of older saved state.

**Acceptance Scenarios**:

1. **Given** a running game in wave 3, **When** the experience is suspended for any wall-clock time and resumed, **Then**
   the wave, its step and every object are unchanged and play continues from the same step.
2. **Given** a saved state from the Phase 01 version, **When** it is restored, **Then** it opens as a run in wave 1 with
   its score, lives, player and objects kept.
3. **Given** a recorded replay, **When** it is played twice, **Then** wave numbers, patterns, score, lives and collision
   events are identical.

### Edge Cases

- **A wall pattern while the player is invulnerable or far from the gap:** the gap is always reachable by the rules of
  story 1 scenario 3; the generator never makes a wall without a gap.
- **Two patterns overlapping at a wave boundary:** objects already falling stay; the new wave's spawns start at its
  first step.
- **The object cap reached during a dense wave:** spawns beyond the cap are skipped as in Phase 01; the pattern
  continues.
- **Difficulty after the ceiling:** waves keep coming with the ceiling values; nothing grows further.
- **Restart in a late wave:** the new run starts in wave 1.
- **A migrated Phase 01 run with objects off the lane centres:** kept as they are; new spawns use lanes.
- **Score overflow:** capped as in Phase 01.

## Requirements *(mandatory)*

### Functional Requirements

**Lanes, waves and difficulty (G-GAMERULES, app-local)**

- **FR-A10-201**: The field MUST have a fixed number of lanes with defined centres; every object spawned by a wave MUST
  start at a lane centre.
- **FR-A10-202**: A wave director MUST run waves of fixed length in sequence; each wave MUST follow one pattern chosen
  by the seeded generator from a data-defined pattern table (at least rain, wall with one gap, zigzag and guarded orb
  trail), every pattern carrying an id, its spawns (offset, lane, kind, content) and an author and license record.
- **FR-A10-203**: Difficulty MUST rise with the wave number — fall speed and spawn density — up to a ceiling; the
  ceiling MUST keep the speed bound that makes capsule collision safe (Phase 01 research D3).
- **FR-A10-204**: A wall MUST always leave exactly one lane free, and that lane MUST be reachable from anywhere in the
  field before the row reaches the player at that wave's speed.
- **FR-A10-205**: The score MUST add survival points per second of play and each orb's value times its wave's
  multiplier, capped as before.

**State and replay**

- **FR-A10-210**: The game run MUST record the wave number, the wave's step and its pattern; the saved state MUST move to
  a new schema and restore the Phase 01 schema through a migration (wave 1 at the saved step).
- **FR-A10-211**: The same seed and inputs MUST give the same waves, patterns, score, lives and collision events;
  suspension MUST NOT advance any of them.

**Experience**

- **FR-A10-220**: The experience MUST draw the lane guides and the wave number, keep every collision shape at its rule
  size, and the spoken description MUST name the wave.
- **FR-A10-221**: The scenario manifest MUST add fixtures for wave progression, the wall gap, background/resume without
  catch-up in a later wave and Phase 01 migration.
- **FR-A10-222**: The pattern table MUST appear in the content license document with author and license.

### Key Entities

- **Lane**: index and centre x.
- **Spawn pattern**: id, name, length in steps, spawns (offset step, lane, kind, content id), author, license.
- **Wave state**: wave number, step within the wave, pattern id.
- **Difficulty**: fall speed range, spawn gap and orb multiplier for a wave, with a ceiling.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A10-201**: Over 20 seeds and 10,000 steps, 100 % of wave-spawned objects start at a lane centre, every wave
  follows a defined pattern, and at least three different patterns appear per seed.
- **SC-A10-202**: Fall speed and spawn density never decrease from one wave to the next and never exceed the ceiling;
  the capsule speed bound holds at the ceiling.
- **SC-A10-203**: 100 % of generated walls leave exactly one free lane, reachable in time from every player position.
- **SC-A10-204**: A suspension of any length leaves wave, step, objects and score identical; a Phase 01 saved state
  restores with score, lives, player and objects kept.
- **SC-A10-205**: Replays give identical waves, score and events in 100 % of repeats.
- **SC-A10-206**: The nine standard scenarios and the fixtures pass on iOS 27; each package test finishes in under 10
  seconds.

## Assumptions

- Exact lane count, wave length, ramp values, multiplier and survival points are set in clarification and tuned in
  A10-P05 balance.
- Glow, particles, sound and haptics come in A10-P03; title, pause and game-over screens (G-TRANSITIONS) in A10-P03;
  local high scores and touch sensitivity settings in A10-P04.

## Out of Scope

- Bosses, power-ups, extra lives, combos beyond the wave multiplier, user-made patterns, high scores.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 01 (player lane, falling hazards, collectible orbs) | FR-A10-201–205; story 1 |
| v0.1 feature 02 (deterministic fixed-step loop, authoritative rules) — Phase 02 MVP | FR-A10-203, 204, 211 |
| v0.1 feature 03 (flows with scores) | FR-A10-205; story 2 |
| Phase 02 regression fixture "background/resume freezes simulation" | FR-A10-211, 221; story 3 |
| Manual §6 `SpawnWave(patternID, spawnTick, hazardDefinitions)`, `WaveDirector` | FR-A10-202, 210 |
| Manual risk 2 (frame-rate-dependent difficulty) | FR-A10-203, 211 |
| Contract gap G-GAMERULES (rest) | FR-A10-201–205, 210 |
| Constitution A10 licenses rule | FR-A10-202, 222 |

## Negative Requirements

- No artwork or recordings; no network; no permission; no online leaderboards, user-generated levels, loot boxes or
  purchasable currency; no claims of skill, reflex, cognitive or health benefits; drawing never changes the game
  state; no second renderer or context; no ProjectM code.
