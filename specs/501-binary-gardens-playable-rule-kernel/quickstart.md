# Quickstart: R02-G21-01

## Run the kernel's tests

`swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens` — the cosine table equals the nearest
integer to 1024·cos(7.5°·k) and its symmetry rules; runs agree with an independent reimplementation of the sky on 500
seeded runs (every position, star share, flux, band, lethal run, window, integral, minimum separation and outcome), and
every body is back at its starting position after 48 ticks; known arrangements win when run; `frozen`, `scorched`,
`unstable`, `wilted` and `bleached` failures named with the world and the tick or the measure, in the judge order
frozen/scorched → unstable → wilted/bleached; a flux one milliflux either side of each of the four bounds, a distance
one unit either side of the clamp radius, a lethal run one tick either side of the tolerance (also across the cycle
boundary, and tolerance 0), a window one tick short of the requirement and the whole cycle comfortable, an integral one
milliflux either side of each bloom bound and a separation one unit either side of the minimum; refusals with reason
codes `r02-g21.*` (out of range, unchanged, locked, breaking the separation, budget, stage, stale); undo (including from
failed), redo and replay fingerprints on 500 seeded traces; stored-form round trips and refusals (damaged, edited,
newer, an invalid value, a starting arrangement that wins or breaks the separation, nothing adjustable) and the nine
invariant tests; each test under 10 s.

## Evidence (gate R02-G21-01)

Every check runs in the foreground through
`python3 scripts/migration_ledger.py run-check --gate R02-G21-01 --name <check> -- <command>` (never a scratchpad
path; recorded only after every agent has reported; read `exit=` before ticking):

| Check | Command |
|---|---|
| `baseline-host` | `swift test --package-path Packages/VisualCore` |
| `baseline-timing` | `env VC_TIMING_ASSERTS=1 swift test --package-path Packages/VisualCore --filter 'aMeshAtTheBudgetBuildsAndValidates\|analysisTimingLevelZeroMeanBelowBudget\|wholeRunForTheSampleTakesLessThanTenSeconds\|aPreparationOverItsLimitTimesOut\|aCancelledPreparationEndsWithinOneSecond'` |
| `baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` | the five round-two filters as at R02-G20-10 (below, without `BinaryGardens`) |
| `host` … `host-5` | `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens` (one per task) |
| `round02-host-1` | `swift test --package-path Packages/ExperiencesRound02 --filter VoxelOrigami` |
| `round02-host-2` | `swift test --package-path Packages/ExperiencesRound02 --filter 'MoonlitMechanism\|AcousticConstellator\|HarmonicBridges\|BinaryGardens'` (gains BinaryGardens) |
| `round02-host-3c` | `swift test --package-path Packages/ExperiencesRound02 --filter 'AuroraLoom\|LissajousLabyrinth\|HueCompass\|WaveKnotKeeper\|ChronoConstellator\|AmethystEscape\|CelestialEclipseLab'` |
| `round02-host-3e` | `swift test --package-path Packages/ExperiencesRound02 --filter 'FacetedForge\|NocturneGarden\|BackwardsAurora\|MicroscopicAurora'` |
| `round02-host-3f` | `swift test --package-path Packages/ExperiencesRound02 --filter 'EchoCartographer\|ColorfallCanyons\|StarlitCartouche\|ApsidesWorkshop\|MushroomWeather'` |
| `rendering-27`, `rendering-26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2` (`sim-26.5`) `--action test` |
| `experiences` | `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test` |
| `host-full` | `swift test --package-path Packages/VisualCore` |
| `reference-1` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` |
| `reference-2` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` |
| `script-tests` | `python3 scripts/test_scripts.py` (run alone: no run-check or tick meanwhile) |

The two reference chunks together are the seven-step ProjectM reference regression (SC-R02G2101-006).

## CI

`.github/workflows/ci.yml`, job `round02-host-tests`, matrix `group: b`: the filter gains `|BinaryGardens` after
`MushroomWeather`; half a is unchanged. Check a run with `gh run list` between steps, never by watching a queued run.
