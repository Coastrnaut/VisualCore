# Quickstart: R02-G01-01

1. `swift test --package-path Packages/ExperiencesRound02` — 1,000 seeded levels win exactly with their constructed
   setting and lose with any single breaking step; boundary samples; 500 traces replay and undo exactly; refused moves
   leave the state unchanged; failures name the worst mismatch; levels round-trip and damaged ones are refused; the rules
   certify with R02-F23's validator.
2. `swift test --package-path Packages/VisualCore` — unchanged.
3. Regression: VisualCoreRendering (sim-27.2, sim-26.5), ExperiencesCreative (sim-27.2), the reference regression in two
   chunks and `python3 scripts/test_scripts.py` (alone).
