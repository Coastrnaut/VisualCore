# Quickstart: R02-G22-01

## Run the kernel's tests

`swift test --package-path Packages/ExperiencesRound02 --filter MyceliumArchitect` — runs agree with an independent
reimplementation of the growth on 500 seeded runs (every field value, step, score, branch, weight, reach pulse, path
weight, node count and outcome), and no network exceeds 2048 nodes; known arrangements win when run; `toxic`,
`starved`, `unreached` and `overweight` failures named with the pulse, tip and cell or the measure, in the judge order
starved/toxic during growth → unreached → overweight; a branch weight one unit either side of the budget and of the
limit, a toxin one cell either side of a tip's path, a terminal one cell beyond the network, equal scores broken by
turn and then direction, corner cutting refused, a negative best score making a tip dormant, a nutrient consumed with a
quarter-turn branch; refusals with reason codes `r02-g22.*` (off the board, not empty, over a count, unchanged, locked
seed, budget, stage, stale); undo (including from failed), redo and replay fingerprints on 500 seeded traces;
stored-form round trips and refusals (damaged, edited, newer, an invalid value, a starting arrangement that wins,
nothing placeable) and the nine invariant tests; each test under 10 s.

## Evidence (gate R02-G22-01)

Every check runs in the foreground through
`python3 scripts/migration_ledger.py run-check --gate R02-G22-01 --name <check> -- <command>` (never a scratchpad
path; recorded only after every agent has reported; read `exit=` before ticking):

| Check | Command |
|---|---|
| `baseline-host` | `swift test --package-path Packages/VisualCore` |
| `baseline-timing` | `env VC_TIMING_ASSERTS=1 swift test --package-path Packages/VisualCore --filter 'aMeshAtTheBudgetBuildsAndValidates\|analysisTimingLevelZeroMeanBelowBudget\|wholeRunForTheSampleTakesLessThanTenSeconds\|aPreparationOverItsLimitTimesOut\|aCancelledPreparationEndsWithinOneSecond'` |
| `baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` | the five round-two filters as at R02-G21-10 (below, without `MyceliumArchitect`) |
| `host` … `host-5` | `swift test --package-path Packages/ExperiencesRound02 --filter MyceliumArchitect` (one per task) |
| `round02-host-1` | `swift test --package-path Packages/ExperiencesRound02 --filter 'VoxelOrigami\|MyceliumArchitect'` (gains MyceliumArchitect) |
| `round02-host-2` | `swift test --package-path Packages/ExperiencesRound02 --filter 'MoonlitMechanism\|AcousticConstellator\|HarmonicBridges\|BinaryGardens'` |
| `round02-host-3c` | `swift test --package-path Packages/ExperiencesRound02 --filter 'AuroraLoom\|LissajousLabyrinth\|HueCompass\|WaveKnotKeeper\|ChronoConstellator\|AmethystEscape\|CelestialEclipseLab'` |
| `round02-host-3e` | `swift test --package-path Packages/ExperiencesRound02 --filter 'FacetedForge\|NocturneGarden\|BackwardsAurora\|MicroscopicAurora'` |
| `round02-host-3f` | `swift test --package-path Packages/ExperiencesRound02 --filter 'EchoCartographer\|ColorfallCanyons\|StarlitCartouche\|ApsidesWorkshop\|MushroomWeather'` |
| `rendering-27`, `rendering-26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2` (`sim-26.5`) `--action test` |
| `experiences` | `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test` |
| `host-full` | `swift test --package-path Packages/VisualCore` |
| `reference-1` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` |
| `reference-2` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` |
| `script-tests` | `python3 scripts/test_scripts.py` (run alone: no run-check or tick meanwhile) |

The two reference chunks together are the seven-step ProjectM reference regression (SC-R02G2201-006).

## CI

`.github/workflows/ci.yml`, job `round02-host-tests`, matrix `group: b`: the filter gains `|MyceliumArchitect` after
`BinaryGardens`; half a is unchanged. Check a run with `gh run list` between steps, never by watching a queued run.
