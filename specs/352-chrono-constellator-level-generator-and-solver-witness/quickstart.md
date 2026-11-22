# Quickstart: R02-G06-02

`swift test --package-path Packages/ExperiencesRound02 --filter ChronoConstellator` — the solver's lower bound and
window checks against an independent brute force on sampled levels; all 100 catalog levels generated per band, their
witnesses replayed to a win and compared byte for byte with `docs/games/chrono-constellator/levels/NNN.witness.json`; the
pinned catalog digest; the progression rule; refusals of edited, newer and damaged witnesses. Regenerate witnesses with
`CHRONO_CONSTELLATOR_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter
ChronoConstellatorCatalogTests`. Each test under 10 s.
