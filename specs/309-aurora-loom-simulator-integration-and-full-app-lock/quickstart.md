# Quickstart: R02-G01-09

```bash
swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomSchemaExampleTests
```

```bash
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-i3
```

```bash
python3 scripts/release_check.py --only app-release-build app-release-symbols
```

```bash
python3 scripts/aurora_loom_regression.py
```
