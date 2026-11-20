# Quickstart: R02-F23

1. `swift test --package-path Packages/VisualCore --filter "PuzzleLevelTests|PuzzleValidatorTests|PuzzleGeneratorTests"`
   — 200 seeded levels round-trip with stable identities and edited forms are refused; 200 levels with planted faults
   fail with exactly the planted verdict; certificates repeat; 100 seeds generate identical certified levels twice; an
   impossible request fails after its attempt budget.
2. `swift test --package-path Packages/VisualCore` — every existing test unchanged.
3. `python3 scripts/check_public_api.py` after `--update` — the new declarations only.
4. Regression: VisualCoreRendering (sim-27.2, sim-26.5), ExperiencesCreative (sim-27.2), the reference regression in two
   chunks and `python3 scripts/test_scripts.py` (alone).
