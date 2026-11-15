# Data Model: A10-P05

- **ArcadeBudget**: `level` 0…2, `glowFactor` (1.2, 1.4, 1.6), `glowOpacityCap` (0.25, 0.30, 0.35), `particleCap`
  (48, 128, 256), `pulse` (false, true, true).
- **Contrast thresholds**: hazard core vs field ≥ 4.5; hazard core vs glow-over-field ≥ 3.0; player and orb vs field ≥ 3.0.
- **SimulatedPlayer**: `idle`, `dodger`, `collector`.
- **BalanceTarget**: idle median wave ≤ 2; dodger median wave ≥ 3; collector median score > dodger median score > idle
  median score; 20 seeds; ≤ 6,000 steps.
- **Registration** (a10): `quality_tiers` ["level-0", "level-1", "level-2"], optional `summary`.
