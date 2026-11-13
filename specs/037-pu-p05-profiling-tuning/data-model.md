# Data Model: A04-P05

- **FrameBudgetMonitor**: budget (s), maxTier, tier (0…maxTier), downWindow 120 frames, upWindow 600 frames, slow
  threshold 1.2×budget with 25% share, fast threshold 0.8×budget with 95% share; counters reset after a change or restart.
- **Profile line**: `PROFILE: {"source":"simulator","experience":"a04.particle-universe", …PerformanceRecord fields…}`.
