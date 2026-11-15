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
- **Alternatives**: islands (more work, not needed at 48 bodies).

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
