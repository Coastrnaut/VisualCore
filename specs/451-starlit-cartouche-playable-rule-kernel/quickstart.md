# Quickstart: R02-G16-01

`swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartouche` — star positions, range decisions,
arrival beats, hazard, window and deadline decisions, stroke sets, mismatch and clearance agree with an independent
recomputation; wins on the exact leg; `window`, `hazard`, `deadline` and `stroke` failures named with the stars,
corridor and beat; budget failure on the exact action (one action either side), one beat either side of each window,
the deadline and a hazard interval, a range one unit inside and outside; refusals with reason codes (unknown star, no
corridor, wait out of range, out of range, stage, stale); undo (including from failed), redo and replay fingerprints;
stored-form refusals and the invariant tests; each test under 10 s.
