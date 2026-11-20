# Quickstart: R02-G02-01

1. `swift test --package-path Packages/ExperiencesRound02` — the sine table matches its pinned digest and `sin` within one
   unit; 500 seeded levels are won by their safe setting; single-dial changes on 50 of them agree with an independent
   reference evaluation; boundary samples on checkpoints and obstacles; 500 traces replay and undo exactly; 1,000 refused
   actions change nothing; failures name the first contact or missing checkpoint; levels round-trip and damaged, edited and
   newer ones are refused; the rules certify with R02-F23's validator; the eight named invariant tests pass; Aurora Loom's
   tests are unchanged.
2. Regression: `swift test --package-path Packages/VisualCore`, VisualCoreRendering (sim-27.2, sim-26.5),
   ExperiencesCreative (sim-27.2), the reference regression in two chunks, `python3 scripts/test_scripts.py` (alone).
