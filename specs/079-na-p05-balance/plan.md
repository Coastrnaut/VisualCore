# Implementation Plan: Neon Arcade — Phase 05 Balance, device QA and storefront

**Branch**: `079-na-p05-balance` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-GLOWCAPS (app-local). Core: `ArcadeBudget` (three levels with glow factor, glow opacity cap, particle cap and
pulse flag; `levels` = 3), `Contrast` (relative-luminance contrast ratio and alpha compositing), `SimulatedPlayer`
(idle, dodger, collector) and `BalanceReport` (median waves and scores over seeds). Experience: `qualityTiers` 3 from
`ArcadeBudget.levels`, `setQualityTier` presentation-only, the presenter draws glow and bursts by the level's budget
(Low Power Mode → level 0, injected; reduced flashing → no pulse), collision shapes above glow at every level;
registration `quality_tiers` level-0…level-2; manifest fixtures 17–19. Storefront: registrations gain an optional
`summary` that `scripts/build_catalog.py` uses in place of the design summary (validated 1…300 characters), set for
a10 to the clarified one-liner; capability words checked against tests. Device campaign: `docs/apps/neon-arcade/
device-campaign.md`. Balance values tuned only where a target is missed (recorded). No VisualCore change.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6; Python 3 (catalog script). **Dependencies**: as A10-P04; `ProcessInfo.isLowPowerModeEnabled`
(injected for tests). **Storage**: none new (the level is not saved; it comes from the host). **Testing**: ExperiencesCreative
on sim-27.2; app build and unit; runner iOS 27; catalog build and script tests; contract; package check.
**Performance**: balance runs 3 players × 20 seeds × ≤ 6,000 steps of pure simulation (measured, < 10 s per test).
**Constraints**: iOS 27; reference regression and iOS 26 at X-A10; device rows pending; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (no context; glow and particles through the existing renderers) · II PASS (tiers via the host's governor; budgets,
contrast and players app-local) · II-a PASS (no VisualCore change) · III PASS (level changes are presentation only) ·
IV PASS (budgets, contrast and balance host-tested) · V PASS (no schema change) · VI PASS (render tests per level on
sim-27.2) · VII PASS (readability, reduced flashing, Low Power) · VIII PASS · IX PASS (caps per level) · X PASS ·
XI–XIII PASS. A10 rules: readability over effects, truthful claims (no benefit claims in the catalog entry), bounded
resources — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/NeonArcade/Core/{ArcadeBudget,Contrast,SimulatedPlayer}.swift               new
Packages/ExperiencesCreative/NeonArcade/CoreTests/{ArcadeBudgetTests,ContrastTests,BalanceTests}.swift   new
Packages/ExperiencesCreative/NeonArcade/Core/{ArcadeCatalog,Difficulty}.swift (only if a target is missed) modify
Packages/ExperiencesCreative/NeonArcade/Experience/Adapter/{ArcadeCore,ArcadeManifest}.swift            modify
Packages/ExperiencesCreative/NeonArcade/Experience/{ArcadePresenter,ArcadeEffectsLayer,
  NeonArcadeExperience}.swift                                                                            modify
Packages/ExperiencesCreative/NeonArcade/ExperienceTests/{ArcadeRenderTests,ArcadeCoreTests,...}.swift   modify
Catalog/registrations.json (a10 quality_tiers, summary), scripts/build_catalog.py (optional summary),
  scripts/test_scripts.py (summary override test), Catalog/experiences.json (rebuilt)                    modify
docs/apps/neon-arcade/{device-campaign.md (new), visualcore-contract.json (G-GLOWCAPS closed), README.md} new/modify
```

**Lifecycle**: the host chooses the tier; the presenter reads the tier in `draw` and Low Power Mode each frame; particles
above a lowered cap are dropped oldest first. **Migration**: none. **Rollback**: revert; the registration keeps working
without `summary`.

## Parallel work

Agent A: core budgets, contrast, simulated players + tests (and tuning if needed). Agent B: experience tiers and drawing
+ tests after A. Agent C: catalog summary override (script + test) and device-campaign document. Lead: registration,
regeneration, contract, runs, commits.
