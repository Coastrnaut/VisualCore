# Implementation Plan: Tiny Worlds — Phase 05 Memory, thermal and content QA

**Branch**: `093-tw-p05-qa` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-DETAIL in the experience, with no VisualCore change: a pure `DetailTier` table (terrain cells per preset and
tier, draws = 2 + props, thumbnail 160 × 120) and a pure `TierPolicy` (tier = max(host level, Low Power floor, memory
floor), the memory floor held 30 s on the presenter's frame clock after the last warning) live in the core; the
presenter applies the policy before drawing, rebuilds only the terrain renderer at most once per tier change, and
records memory warnings in `shedCaches()`; the factory injects Low Power Mode (`lowPowerMode`) as Physics Playground
does. Fixtures prove the tier sequences, the unchanged digest, 20 stale-object cycles and saved-world round trips across
tiers and packs. A README capability table, a claims scan and the device-campaign document complete the truthful
catalog entry and the device plan. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
Contract: [contracts/detail-tiers.md](contracts/detail-tiers.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: unchanged — `ExperienceShell.setQualityTier(_:)` and `qualityProfile`
(VisualCoreExperienceHost), `ExperiencePresenter.shedCaches()` (called by `ExperienceShell.shedCaches()` on a memory
warning), `ResourceRegistry.stats` (`ResourceLedger.Snapshot` with `liveCount`, `liveBytes`, `leaked`),
`ExperienceSession.recreateContext()`, `diagnostics.lastCloseCounts`, `TerrainDetail.columns/rows(preset:level:)`,
`ProcessInfo.processInfo.isLowPowerModeEnabled`. **Storage**: unchanged (state schema 2; saved documents schema 2).
**Testing**: ExperiencesCreative on sim-27.2 (TinyWorldsCoreTests, TinyWorldsExperienceTests); app build and unit;
runner iOS 27; experience packages; contract; claims scan; catalog; script tests. **Performance**: counted (vertices,
draws, rebuilds), never timed. **Constraints**: tests < 10 s; no wall-clock asserts; iOS 27 only; reference regression
and iOS 26 at X-A12; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one app; experience module only) · II PASS (tier table and policy app-local, as the contract assigns G-DETAIL;
host quality tiers and `shedCaches()` reused) · II-a N/A (no VisualCore change, no API baseline change) · III PASS (Low
Power Mode lowers drawing only) · IV PASS (policy and table tested without GPU; cycles through the host) · V PASS (no
schema change; digest independent of tier) · VI PASS (code-only visuals, no new content) · VII PASS (tiers never remove
labels or controls) · VIII PASS (no network) · IX PASS (stated counts, at most one rebuild per change) · X PASS
(truthful claims scan) · XI–XIII PASS. A12 rules: bounded, truthful claims; world authority independent of quality —
PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/TinyWorlds/Core/{DetailTier,TierPolicy}.swift                                    new
Packages/ExperiencesCreative/TinyWorlds/CoreTests/{DetailTierTests,TierPolicyTests}.swift                     new
Packages/ExperiencesCreative/TinyWorlds/Experience/{WorldsPresenter,TinyWorldsExperience}.swift               modify
Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/{WorldsQualityTests,WorldsStaleObjectTests}.swift     new
Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/WorldStoreTests.swift (tiers × packs round trip)       modify
Packages/ExperiencesCreative/TinyWorlds/scenario-manifest.json, Experience/Adapter/WorldsManifest.swift        modify/regenerate
Catalog/registrations.json (a12.tiny-worlds summary, capabilities; quality_tiers level-0…2 unchanged)          check/modify
docs/apps/tiny-worlds/{README.md (Capabilities and their proof), device-campaign.md}                           modify/new
docs/apps/tiny-worlds/visualcore-contract.{json,md} (G-DETAIL closed by A12-P05)                               modify
specs/093-tw-p05-qa/scan-claims.sh                                                                             new
```

**Dependency direction**: unchanged (Experience → Core → VisualCore; Core imports no host or UIKit). **Lifecycle**:
the presenter evaluates `TierPolicy` once per frame before drawing, with the host tier the shell passes, Low Power Mode
read now and its own frame clock (sum of frame deltas since the presenter was made; it does not reset on `setup`);
`shedCaches()` records a warning at the current clock and drops CPU caches; `teardown` releases every renderer; the
core stores no tier. **Migration**: none (no schema change). **Rollback**: revert the commits; the presenter's previous
behaviour (level = host tier) is the policy with no pressure.

## Parallel work

Agent A: `DetailTier`, `TierPolicy` and their core tests. Agent B (after A): presenter, factory, experience tests
(quality, stale objects, store round trip). Agent C (parallel to A): README capability table, device-campaign document,
claims scan (documents only). Lead: manifest, registration, contract, regeneration, runs, commits.
