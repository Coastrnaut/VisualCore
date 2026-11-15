# Research: A09-P05 Ambient device testing and release content

Facts verified on 2026-11-14 (clarification session): `ExperienceStorage` API and quota, `ScopePresetStore`'s file and
action pattern, the host's tier in `draw`, `setQualityTier`, the session's `lowPower`, `ResourceRegistry.stats`.

## D1 — Saved configurations

- **Decision**: `AquariumConfiguration` (format 1: `format`, `id`, `name`, `savedAt`, `habitatIndex`, `lighting`,
  `decorKind`, `ambient`, `decor` [kind, x, y, rotation, scale]); `from(state:name:id:savedAt:)`; `validate(catalog:)`;
  `actions(catalog:)` → `[(control, values)]`: `habitat.select [i]`, then `decor.remove [0]` × starter count, then per
  piece `decor.kind [k]`, `decor.place [x/16, y/9]`, `decor.turn [index, rotation, scale]`, then `decor.kind`
  (saved), `lighting.level`, `ambient.mode`. `AquariumLibrary` (main actor, observable): entries sorted by name ignoring
  case (ties by id), `save(name:state:)`, `open(_:port:)`, `delete(_:)`, `unreadable`, `newer`, `lastFailure`, limit 12.
- **Rationale**: the port is the only way a presenter changes state (verified); a configuration is what a person
  arranges.
- **Alternatives**: whole-state snapshots in files restored through the session (presenters cannot reach the shell's
  restore).

## D2 — Ambient

- **Decision**: `AquariumSimulation.advance(_:catalog:random:ambient:)` with cruise × 0.6 (floor 0.5 × the scaled
  cruise); ambient drawing = saved `ambient` OR Low Power Mode OR Reduce Motion (presenter, injected closures).
- **Alternatives**: Low Power changing the simulation (would make the digest depend on the device).

## D3 — Dimmer

- **Decision**: `AmbientDimmer` value type: `idleInterval` 60, `fadeDuration` 2, `dimLevel` 0.6; `advance(by:active:)`
  adds frame time while ambient drawing is active; `touch()` resets to 0; `brightness` = 1 until 60 s, then a linear fade
  to 0.6 over 2 s. Presenter multiplies every lit colour and the caustics' colours by `brightness`.

## D4 — Budgets

- **Decision**: `AquariumBudget.for(tier:ambient:) -> (bubblesPerVent, motes, causticsOctaves)`: level 0 (24, 24, 2),
  level 1 (12, 12, 1), level 2 (6, 6, 0); ambient (12, 12, 2); combined by the minimum. `WaterEffects.bubbles(... ,
  perVent:)` and `motes(..., count:)` take the limits.

## D5 — Long run and memory

- **Decision**: `LongRunTests` (core): 3 seeds × 10,000 steps, a feed every 100 steps, checks every 50th step;
  `AquariumSessionTests`: open and close five times, compare `ResourceRegistry.stats` (live counts) after each open.
  Fixtures 12 and 13 as in the clarifications.

## D6 — Device campaign

- **Decision**: `docs/apps/digital-aquarium/device-campaign.md` modelled on Oscilloscope Studio's: rows for frame time
  per level and view state, ten-minute thermal run in ambient, memory after reopening and after saving 12 aquariums,
  dimming timing, saved aquariums across relaunch, VoiceOver, Dynamic Type, Reduce Motion, Low Power Mode, contrast;
  all pending; D1 → D2 → D3, D3 stays on iPadOS 26.5.
