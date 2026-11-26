# Quickstart: R02-G19-09

```bash
swift test --package-path Packages/ExperiencesRound02 --filter MicroscopicAuroraSchemaExampleTests
```

```bash
xcodegen generate --spec project.yml
```

```bash
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-b4
```

```bash
python3 scripts/release_check.py --only app-release-build app-release-symbols
```

```bash
python3 scripts/microscopic_aurora_regression.py
```

Expected: every command exits 0; the interface tests win level 1, keep progress over a relaunch and replay the win.
