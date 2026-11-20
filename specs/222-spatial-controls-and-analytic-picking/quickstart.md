# Quickstart: R02-F22

1. `swift test --package-path Packages/VisualCore --filter "ScreenProjectionTests|HandlePickerTests|HandleDragTests|ControlHistoryTests|AssistiveStepTests"`
   — rays through projected points for 1,000 seeded cameras; plane hits on their planes; picks equal the rule for 200
   seeded handle sets; drags return exactly and hold at grazing angles; histories undo and redo exactly and coalesce a
   500-event drag; assistive steps return exactly with descriptions.
2. `swift test --package-path Packages/VisualCore` — every existing test unchanged.
3. `python3 scripts/check_public_api.py` after `--update` — the new declarations only.
4. Regression: VisualCoreRendering (sim-27.2, sim-26.5), ExperiencesCreative (sim-27.2, Effects Composer), the
   reference regression in two chunks and `python3 scripts/test_scripts.py` (alone).
