# Quickstart: R02-G07-02

`swift test --package-path Packages/ExperiencesRound02 --filter AmethystEscape` — the solver agrees with an independent
brute force, all 80 catalog levels are certified with witnesses that replay, the pinned catalog digest, the progression
rule, witness files equal to the regenerated ones byte for byte; each test under 10 s.

Regenerating the witness files on purpose: `AMETHYST_ESCAPE_WRITE_WITNESSES=1 swift test --package-path
Packages/ExperiencesRound02 --filter AmethystEscapeCatalogTests`, then commit the files with the change.
