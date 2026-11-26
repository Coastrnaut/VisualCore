# Quickstart: R02-G19-01

`swift test --package-path Packages/ExperiencesRound02 --filter MicroscopicAurora` — swims agree with an independent
reimplementation of the tick law on 500 seeded swims (every position, density, lit cell, coverage, group, coherence and
outcome); known wells win when played; `exit`, `coherence`, `coverage` and `connectedness` failures named with the
swimmer or cell and the tick; a swimmer on the rim and one unit outside, a density at and one below the threshold, a
coverage one cell either side of the requirement and a coherence one swimmer either side; refusals with reason codes
(out of range, unchanged, occupied or outside cell, budget, stage, stale); undo (including from failed), redo and
replay fingerprints; stored-form refusals (a swimmer outside, an incoherent start, starting wells already winning,
damaged, newer) and the invariant tests; each test under 10 s.
