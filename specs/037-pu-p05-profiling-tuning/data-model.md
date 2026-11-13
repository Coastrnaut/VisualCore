# Data Model: A04-P05

- **FrameBudgetMonitor**: budget (s), maxTier, tier (0…maxTier), downWindow 120 frames, upWindow 600 frames, slow
  threshold 1.2×budget with 25% share, fast threshold 0.8×budget with 95% share; counters reset after a change or restart.
- **FrameIntervalEstimate** (T-A04-516, research D7): interval (s, nil until seen) = smallest accepted step between
  consecutive target timestamps (1/240 s … 0.1 s); last (index, target); reset on setup and teardown. The monitor's
  budget follows it when they differ by more than 10%.
- **Profile line**: `PROFILE: {"source":"simulator","experience":"a04.particle-universe", …PerformanceRecord fields…}`.
