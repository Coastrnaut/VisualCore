# Research: A10-P05 Balance, device QA and storefront

Facts verified on 2026-11-14: see spec Clarifications; `scripts/build_catalog.py` takes the summary from the planning
catalog's design (`summary` or `pitch`) and allows only the keys capabilities, quality_tiers, palette, content plus
optional manifest and permissions in a registration.

## D1 — Budgets
- **Decision**: `ArcadeBudget.levels = 3`; level 2 (1.6, 0.35, 256, pulse), level 1 (1.4, 0.30, 128, pulse), level 0
  (1.2, 0.25, 48, no pulse); glow alpha = min(cap, base + pulse); burst count = max(1, round(n × cap / 256)).
- **Alternatives**: continuous scaling (harder to declare and test).

## D2 — Contrast
- **Decision**: sRGB relative luminance (WCAG 2.x), ratio (L1 + 0.05)/(L2 + 0.05); compositing glow over field with the
  level's maximum opacity; thresholds per clarification 2.

## D3 — Simulated players and targets
- **Decision**: per clarification 3; each player reads the current `GameRun` and returns a steering value applied as a
  recorded `run.steer` each step it changes; median over 20 seeds; runs end at game over or 6,000 steps.

## D4 — Catalog summary
- **Decision**: optional registration key `summary` (string, 1…300 characters) overriding the design summary in
  `Catalog/experiences.json`; a test in `scripts/test_scripts.py` covers present, absent and invalid.

## D5 — Fixtures
- **Decision**: fixtures 17–19: a 600-step run at level 0, 1 and 2 recorded as the same digest (levels are presentation
  only; the render tests prove the per-level caps); the level change mid-run is proved by a render test.
