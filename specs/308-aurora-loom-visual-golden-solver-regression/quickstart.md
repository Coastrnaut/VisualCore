# Quickstart: R02-G01-08

```bash
swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomRegression
```

Expect the solver regression (100 levels, 12 alterations) and the golden digests to pass. After a deliberate visual
change, regenerate and commit the baseline:

```bash
AURORA_LOOM_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomRegressionGoldenTests
```

Whole regression (host and simulator, one summary):

```bash
python3 scripts/aurora_loom_regression.py
```
