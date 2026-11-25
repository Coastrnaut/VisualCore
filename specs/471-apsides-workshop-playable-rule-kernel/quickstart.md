# Quickstart: R02-G18-01

`swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshop` — positions agree with an independent
`Double` Kepler solution within 2 sky units and every residual is within 2^−22; sectors, shares, apsis readings,
contact decisions and the judge agree with a direct recomputation on the kernel's positions; known orbits win when
played; `contact`, `order`, `share`, `apsis-sector` and `apsis-distance` failures named with the target or planet and
the tick; one unit either side of a share band and a distance range, a planet one unit inside and outside contact;
refusals with reason codes (out of range, unchanged, invalid orbit, budget, stage, stale); undo (including from
failed), redo and replay fingerprints; stored-form refusals (invalid orbit, planet over the star, starting orbit already
winning, damaged, newer) and the invariant tests; each test under 10 s.
