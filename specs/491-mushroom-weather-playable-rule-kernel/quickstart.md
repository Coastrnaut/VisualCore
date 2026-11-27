# Quickstart: R02-G20-01

`swift test --package-path Packages/ExperiencesRound02 --filter MushroomWeather` — runs agree with an independent
reimplementation of the cycle law on 500 seeded runs (every humidity value, ledger entry, growth cycle, colony run and
outcome), and the ledger balances for every cycle; known arrangements win when run; `dried`, `mold` and `unstable`
failures named with the colony or cell and the cycle; a colony one unit either side of a band edge, a cell one unit
either side of the mold bound, a sensitive colony one unit either side of its floor, a growth integral one unit either
side of its threshold and a final run one cycle short; refusals with reason codes (out of range, unchanged, forbidden
cell, empty slot, budget, stage, stale); undo (including from failed), redo and replay fingerprints; stored-form
refusals (a colony below its floor, a cell above the mold bound, a starting arrangement that wins, damaged, newer) and
the invariant tests; each test under 10 s.
