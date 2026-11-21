# Quickstart: R02-G04-02

`swift test --package-path Packages/ExperiencesRound02 --filter "HueCompassSolverTests|HueCompassWitnessTests|HueCompassGeneratorTests|HueCompassCatalogTests"`
— solver against an independent brute force, soundness of every witness selection, counterexamples, the 100 witness
files byte for byte (one test per band), the pinned catalog digest and the progression rule; each test under 10 s.
Regenerate the witness files on purpose with `HUE_COMPASS_WRITE_WITNESSES=1` and the same command.
