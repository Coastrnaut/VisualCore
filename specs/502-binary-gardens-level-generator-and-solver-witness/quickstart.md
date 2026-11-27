# Quickstart: R02-G21-02

`swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens` — the kernel extension (a phase step
round-trips with its fingerprint; "phase step" and "phase off grid" refused in order; the play and the puzzle refuse an
off-grid phase with "off the phase grid"; a level without a step keeps its feature-501 stored form and pinned
fingerprint); the solver's minimum agrees with an independent enumeration of every action sequence shorter than the
plan through the puzzle's moves, with no visited set and no loss order, on the two levels with the smallest move space
in each band; every catalog level is generated from its manifest entry, won by its witness within the budget and not by
any arrangement reachable with fewer actions; adjacent levels have different ring radii or worlds; the catalog digest
is pinned; the progression rule holds and band means do not fall; the 100 witness files match byte for byte (regenerate
only with `BINARY_GARDENS_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter
BinaryGardensCatalogTests --no-parallel`); edited, newer and damaged witnesses are refused; the content and novelty
boundary tests pass with their neighbouring-input checks; each certification group of 5 levels under 10 s (measured
locally, never asserted on CI).

## Evidence (`python3 scripts/migration_ledger.py run-check --gate R02-G21-02 --name <name> -- <command>`)

| Name | Command |
|---|---|
| `baseline-host`, `host-full` | `swift test --package-path Packages/VisualCore` |
| `baseline-timing` | `env VC_TIMING_ASSERTS=1 swift test --package-path Packages/VisualCore --filter 'aMeshAtTheBudgetBuildsAndValidates\|analysisTimingLevelZeroMeanBelowBudget\|wholeRunForTheSampleTakesLessThanTenSeconds\|aPreparationOverItsLimitTimesOut\|aCancelledPreparationEndsWithinOneSecond'` |
| `baseline-round02-1`, `round02-host-1` | `swift test --package-path Packages/ExperiencesRound02 --filter VoxelOrigami` |
| `baseline-round02-2`, `round02-host-2` | `swift test --package-path Packages/ExperiencesRound02 --filter 'MoonlitMechanism\|AcousticConstellator\|HarmonicBridges\|BinaryGardens'` |
| `baseline-round02-3c`, `round02-host-3c` | `swift test --package-path Packages/ExperiencesRound02 --filter 'AuroraLoom\|LissajousLabyrinth\|HueCompass\|WaveKnotKeeper\|ChronoConstellator\|AmethystEscape\|CelestialEclipseLab'` |
| `baseline-round02-3e`, `round02-host-3e` | `swift test --package-path Packages/ExperiencesRound02 --filter 'FacetedForge\|NocturneGarden\|BackwardsAurora\|MicroscopicAurora'` |
| `baseline-round02-3f`, `round02-host-3f` | `swift test --package-path Packages/ExperiencesRound02 --filter 'EchoCartographer\|ColorfallCanyons\|StarlitCartouche\|ApsidesWorkshop\|MushroomWeather'` |
| `host` (kernel extension), `host-2` (solver), `host-3` (generator), `host-4` (witness), `host-5` (catalog) | `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens` |
| `rendering-27` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test` |
| `rendering-26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test` |
| `experiences` | `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test` |
| `reference-1` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` |
| `reference-2` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` |
| `script-tests` (alone; no run-check or tick writes the ledger meanwhile) | `python3 scripts/test_scripts.py` |

Binary Gardens is in the local round-two chunk 2 (since feature 501) and in CI's `round02-host-tests` half b; no
workflow change. The baselines run on the committed tree after R02-G21-01 is recorded, before any source edit of this
feature. The `\|` above is table escaping: the filters are written with a plain `|` inside single quotes.
