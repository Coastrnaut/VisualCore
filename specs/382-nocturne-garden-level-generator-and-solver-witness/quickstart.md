# Quickstart: R02-G09-02

`swift test --package-path Packages/ExperiencesRound02 --filter NocturneGarden` — the 100-entry manifest, the band
profiles, candidates built from their seeds, the solver's lower bound and its exact-length solutions, the independent
brute-force bound on two levels per band, the witnesses replayed and compared byte for byte with
`docs/games/nocturne-garden/levels/`, the pinned catalog digest and the progression rule; certification in groups of 5
levels. Regenerating the witnesses on purpose: `NOCTURNE_GARDEN_WRITE_WITNESSES=1 swift test --package-path
Packages/ExperiencesRound02 --filter NocturneGardenCatalogTests`.
