# Quickstart: R02-F24

1. `swift test --package-path Packages/VisualCore --filter "ProgressionRuleTests|PuzzleCatalogTests|PuzzleCatalogCheckerTests|TutorialContractTests"`
   — a 3-stage, 30-level plan builds twice into identical catalogs with the pinned digest; every level certifies and the
   progression holds; 100 planted catalog faults are reported exactly; 100 tutorial scripts advance as their conditions
   say; stored forms round-trip and edited ones are refused.
2. `swift test --package-path Packages/VisualCore` — every existing test unchanged.
3. `python3 scripts/check_public_api.py` after `--update` — the new declarations only.
4. Regression: VisualCoreRendering (sim-27.2, sim-26.5), ExperiencesCreative (sim-27.2), the reference regression in two
   chunks and `python3 scripts/test_scripts.py` (alone).
