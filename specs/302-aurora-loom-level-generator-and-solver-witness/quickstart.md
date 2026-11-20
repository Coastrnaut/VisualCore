# Quickstart: R02-G01-02

1. `swift test --package-path Packages/ExperiencesRound02` — the solver agrees with an independent exhaustive per-ribbon
   check (full win test) on every catalog level and 500 seeded levels; descent and grid agree; all 100 levels generate twice identically,
   the digest equals the pinned value, the progression rule and band means hold, every witness replays to a win within the
   allowance and equals its file in `docs/games/aurora-loom/levels/` byte for byte; edited, newer and damaged witnesses
   are refused; each counterexample loses with a named ribbon, gate and tick.
2. Regenerate the witness files after an intended rule change:
   `AURORA_LOOM_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomCatalogTests`
   (then review the diff and re-pin the digest).
3. Regression: `swift test --package-path Packages/VisualCore`, VisualCoreRendering (sim-27.2, sim-26.5),
   ExperiencesCreative (sim-27.2), the reference regression in two chunks, `python3 scripts/test_scripts.py` (alone).
