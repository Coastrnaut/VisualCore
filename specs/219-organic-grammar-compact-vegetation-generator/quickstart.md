# Quickstart: R02-F19

1. `swift test --package-path Packages/VisualCore --filter "PlantGrammarTests|PlantTurtleTests|PlantShapesTests|PlantMeshTests|PlantScatterTests"`
   — hand-derived grammars give their words and branch counts; seeded grammars repeat and differ by seed; every shape
   validates within budget at its stated size; plant meshes place parts at markers; scatters keep their spacing and
   repeat; grammars round-trip.
2. `swift test --package-path Packages/VisualCore` — every existing test unchanged.
3. `python3 scripts/check_public_api.py` after `--update` — the new declarations only.
4. Regression: ExperiencesCreative (sim-27.2), VisualCoreRendering (sim-27.2, sim-26.5), the reference regression in two
   chunks and `python3 scripts/test_scripts.py`.
