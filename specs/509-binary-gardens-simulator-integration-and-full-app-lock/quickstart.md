# Quickstart: R02-G21-09

Only after R02-G21-08 is recorded (`python3 scripts/migration_ledger.py status`).

```bash
swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardensSchemaExampleTests
```

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package \
  --destination sim-27.2 --action test --only-testing BinaryGardensExperienceTests
```

```bash
grep -n '"d4"' scripts/release_check.py && xcodegen generate --spec project.yml
```

```bash
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-d4
```

```bash
python3 scripts/release_check.py --only app-release-build app-release-symbols
```

```bash
python3 scripts/binary_gardens_regression.py
```

Expected: every command exits 0 (the grep finds exactly the one new `"d4"` entry); the interface tests win level 1,
keep progress over a relaunch and replay the win.
