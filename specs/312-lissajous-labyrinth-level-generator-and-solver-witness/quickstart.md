# Quickstart: R02-G02-02

1. Host tests (solver, witness, generator, catalog by band):
   `swift test --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinth` — all pass, each test < 10 s.
2. Regenerate the witnesses after an intended rule change (then commit them):
   `LISSAJOUS_LABYRINTH_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinthCatalogTests`
3. Expect: 100 files in `docs/games/lissajous-labyrinth/levels/`, each replaying to a win within its allowance; the pinned
   catalog digest unchanged on a second run; an edited witness refused with `r02-g02.witness`.
