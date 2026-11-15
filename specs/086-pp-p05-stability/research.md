# Research: A11-P05 (feature 086)

Facts verified on 2026-11-15 (clarification session).

## D1 — Sleep

- **Decision**: per body `asleep: Bool`, `restTicks: Int` (world schema 4). After integration each tick, an awake
  dynamic body below 0.05 m/s and 0.05 rad/s increments `restTicks`, else resets it; at 60 it sleeps (velocities 0).
  Before contacts, wake triggers are applied: broad-phase overlap of a sleeping body's bounds with an awake dynamic
  body's bounds; a spring with one awake dynamic end; edits naming the body (and bodies whose bounds touch a deleted
  one); any level change wakes all. Sleeping bodies get no gravity, drag or integration; pairs where neither side is an
  awake dynamic body are skipped before the narrow phase.
- **Rationale**: the textbook resting-contact optimisation with conservative, deterministic triggers.
- **Alternatives**: islands (more work, not needed at 48 bodies) — superseded at implementation, see below.
- **As built (T-A11-502)**: (1) bodies that touch (overlapping bounds) or share a spring between two dynamic bodies
  fall asleep together: a group sleeps only when every member has 60 rest ticks and none is grabbed (static and pinned
  bodies and walls never join a group), because a body sleeping alone was woken again at once by its awake neighbour
  and a stack never settled. (2) A body joined by a spring to a world point or to a static or pinned body never sleeps
  (its rest counter stays 0): with damping 0.1 a hanging body's speed stays below 0.05 m/s through small swings, and it
  froze mid-swing; with the rule the A11-P02 hanging-box tests pass unchanged. Measured on the host: the stack is
  asleep after 62 ticks with 0 narrow-phase tests; stress 5 seeds × 1,200 ticks with 0 bad values; unedited damped
  energy rise ≤ 0.041 %/s; work at 48 awake bodies ≤ 79 narrow-phase tests, 68 points, 680 solver updates per tick;
  median tick 0.72 ms (debug host, not asserted; device timing is PP-D1).

## D2 — Work count and timing

- **Decision**: `WorkCount { narrowPhaseTests, contacts, contactPoints, solverPointUpdates }` returned by a measured
  tick variant (derived, not saved). Budget asserts: narrowPhaseTests ≤ 1,320; contactPoints ≤ 2 × contacts;
  solverPointUpdates ≤ iterations × contactPoints. A host measurement (median tick time over 600 ticks at 48 awake
  bodies and 16 springs) is recorded below at implementation, never asserted (no wall-clock asserts on CI).

## D3 — Quality levels

- **Decision**: `DrawingBudget.levels` (3): coils 8/6/4, circle segments 33/24/16, hatch spacing 0.12/0.2/none,
  arrowheads on/on/on; budget level = Low Power Mode ? 2 : host tier (tier 0 best). Core `qualityTiers` 3 with the
  profile `level-0…level-2` matching the registration.

## D4 — Fixtures

- **Decision**: manifest fixtures 34 stress (one seed, 600 steps), 35 settle to sleep (stack preset), 36 wake by hit,
  37 replay across levels (digest equal), 38 schema-4 migration. Stress over five seeds and 1,200 ticks runs in the core
  tests (host-free, < 10 s total measured).

## D5 — Storefront and device plan

- **Decision**: the clarified summary and capabilities; README table capability → test; `scan-claims.sh` modelled on
  `specs/079-na-p05-balance/scan-claims.sh`; `device-campaign.md` rows: frame pacing per level on the reference phone
  and tablet, thermal state over 10 minutes at 48 bodies, touch latency for grab, VoiceOver pass — status "pending
  device campaign".
