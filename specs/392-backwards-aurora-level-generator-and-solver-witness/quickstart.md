# Quickstart: R02-G10-02

`swift test --package-path Packages/ExperiencesRound02 --filter BackwardsAurora` — the 100-entry manifest, the band
profiles, candidates built from their seeds, the seam-count bound and the solver's solutions at that bound, the
independent checks (bad bends recomputed, no single reversal removing more than 4, exhaustive search on two band-1
levels), the witnesses replayed and compared byte for byte with `docs/games/backwards-aurora/levels/`, the pinned
catalog digest and the progression rule; certification in groups of 5 levels. Regenerating the witnesses on purpose:
`BACKWARDS_AURORA_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter
BackwardsAuroraCatalogTests`.
