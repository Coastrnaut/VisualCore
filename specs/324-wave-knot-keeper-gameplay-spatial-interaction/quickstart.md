# Quickstart: R02-G03-04

```bash
swift test --package-path Packages/ExperiencesRound02 --filter "WaveKnotKeeperHandlesTests|WaveKnotKeeperGestureControllerTests|WaveKnotKeeperPanelWinTests|WaveKnotKeeperSceneGeometryTests"
```

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
```

Expected: every test passes; scripted drags make exactly the moves their directions imply; all 100 levels are won through
the panel's actions.
