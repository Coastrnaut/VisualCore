# Quickstart: R02-G07-09

```bash
swift test --package-path Packages/ExperiencesRound02 --filter AmethystEscapeSchemaExampleTests
```

```bash
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-p3
```

```bash
python3 scripts/release_check.py --only app-release-build app-release-symbols
```

```bash
python3 scripts/amethyst_escape_regression.py
```

Expected: every command exits 0; the interface tests win level 1, keep progress over a relaunch and replay the win.
