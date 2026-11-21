# Quickstart: R02-G03-02

```bash
swift test --package-path Packages/ExperiencesRound02 --filter WaveKnotKeeper
```

```bash
WAVE_KNOT_KEEPER_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter WaveKnotKeeperCatalogTests
```

Expected: every test passes; the second command (opt-in only) rewrites `docs/games/wave-knot-keeper/levels/*.witness.json`,
after which `git diff` must be empty on a rerun.
