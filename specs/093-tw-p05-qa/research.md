# Research: A12-P05 (feature 093)

Facts verified on 2026-11-15 (clarification session and the plan's read-only audit of `WorldsPresenter.swift`,
`ExperienceShell.swift`, `ExperiencePresenter.swift`, `ResourceRegistry.swift`, `TerrainDetail.swift`,
`WorldsSessionTests.swift` and `PlaygroundPresenter.swift`).

## D1 — Tier table

- **Decision**: `DetailTier` (core): tier i draws terrain level i (`TerrainDetail.columns/rows(preset:level:)`:
  64/32/16 cells, city 48/24/12); draws per frame = world parts + props (terrain, the sea for the island and the city, each prop once); thumbnail 160 × 120 at
  every tier. Terrain vertices = (cols + 1) × (rows + 1) at each tier, strictly decreasing.
- **Rationale**: the props and the sea are part of the world; removing them would change what the person sees and
  saves. The terrain carries almost all vertices.
- **Alternatives**: prop caps per tier (rejected: changes the world shown); smaller thumbnails (rejected: a slot's
  picture would differ with heat).

## D2 — Tier policy

- **Decision**: `TierPolicy` (core, value type): `tier(host:lowPower:now:)` = max(clamp(host, 0…2), lowPower ? 2 : 0,
  memoryHeld(now) ? 2 : 0); `recordMemoryWarning(at:)` sets `lastWarning`; held while now − lastWarning < 30 s.
  Thermal steps and their hold come from the host's `QualityGovernor` (already ≤ one change per second; step up only
  after the hold), so the experience adds no thermal reading. The clock is the presenter's frame clock (sum of frame
  deltas), deterministic in tests.
- **Rationale**: one rule set, no wall clock, testable without GPU; the host keeps thermal authority.
- **Alternatives**: own thermal observer (rejected: duplicates the governor); wall-clock hold (rejected: tests).

## D3 — Rebuilds

- **Decision**: the presenter rebuilds only the terrain renderer when the policy's tier changes (existing
  `rebuildTerrainRenderer`), counted by `terrainBuildCount`; repeated warnings at the lowest tier cause no rebuild.
  `shedCaches()` keeps dropping CPU caches (parts, levels, ground field) as before; the renderers stay.
- **Rationale**: the existing path already rebuilds once per level change.

## D4 — Stale-object fixture

- **Decision**: `WorldsStaleObjectTests`: one session, 20 cycles of open pack (cycling the three), save slot 0 and
  open it, set the host tier (cycling 0…2), recreate the context, close and reopen the session; after each cycle the
  registry's `liveCount` and `liveBytes` equal cycle 1's and `leaked` is 0; each close leaves
  `lastCloseCounts.objects` 0. Budget: about 20 × 6 frames; measured under 10 s on the host.
- **Rationale**: the manual's regression fixture, bounded short.

## D5 — Truthful catalog entry and device plan

- **Decision**: README "Capabilities and their proof" (one row per registered capability, "File.swift testName");
  `scan-claims.sh` modelled on `specs/086-pp-p05-stability/scan-claims.sh` with the clarified refused words (accurate,
  accuracy, precise, precision, scientific, realistic, real-world, geographic, fps, frames per second, battery, and a
  number followed by ms); `device-campaign.md` TW-D1 frame pacing per tier, TW-D2 thermal state over a 10-minute run,
  TW-D3 memory high-water mark across pack switches, TW-D4 touch latency of orbit and place, TW-D5 accessibility audits;
  status "pending device campaign", tagged {device}.

## As built (2026-11-15)

- `DetailTier` and `TierPolicy` in the core as decided (D1, D2); the draw count is the world parts (2; asteroid garden
  1, which has no sea) plus props, corrected at analyze from the first "2 + props".
- The presenter evaluates the policy first in `draw` (`applyPressure(hostTier:delta:)`), exposes `lastTier`,
  `lastHostTier` and `terrainVertices` (the terrain mesh's position count) for the tests, and records a warning in
  `shedCaches()`; the shell's `shedCaches()` (the host's memory-warning path) reaches it.
- Measured on the iOS 27.2 simulator, recorded and not asserted: the 20-cycle stale-object fixture ran in 1.058 s, the
  seven quality tests in 0.197 s and the tiers × packs round trip within the 70 experience tests' 6.1 s.
