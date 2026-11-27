# Quickstart: R02-G21-03

Every check is recorded with `python3 scripts/migration_ledger.py run-check --gate R02-G21-03 --name <name> -- <command>`
(never a scratchpad path; one runner at a time; no source edits while a chain runs). Names follow feature 493's.

1. Baselines on the committed tree after R02-G21-02 is recorded:
   - `baseline-host` — `swift test --package-path Packages/VisualCore`
   - `baseline-timing` — `env VC_TIMING_ASSERTS=1 swift test --package-path Packages/VisualCore --filter
     'aMeshAtTheBudgetBuildsAndValidates|analysisTimingLevelZeroMeanBelowBudget|wholeRunForTheSampleTakesLessThanTenSeconds|aPreparationOverItsLimitTimesOut|aCancelledPreparationEndsWithinOneSecond'`
   - `baseline-round02-1` — `swift test --package-path Packages/ExperiencesRound02 --filter VoxelOrigami`
   - `baseline-round02-2` — `swift test --package-path Packages/ExperiencesRound02 --filter
     'MoonlitMechanism|AcousticConstellator|HarmonicBridges|BinaryGardens'`
   - `baseline-round02-3c` — `… --filter
     'AuroraLoom|LissajousLabyrinth|HueCompass|WaveKnotKeeper|ChronoConstellator|AmethystEscape|CelestialEclipseLab'`
   - `baseline-round02-3e` — `… --filter 'FacetedForge|NocturneGarden|BackwardsAurora|MicroscopicAurora'`
   - `baseline-round02-3f` — `… --filter 'EchoCartographer|ColorfallCanyons|StarlitCartouche|ApsidesWorkshop|MushroomWeather'`
2. Host, per Core task (each test < 10 s): `host` (package, snapshot, palette, tiers, kernel-file scans), `host-2`
   (shader sources), `host-3` (geometry, cube-sphere, camera, CPU reference), `host-4` (adapter and purity),
   `scenarios` (scenario manifest) — all `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`:
   adapter conformance, undo restores the digest, `clock.show` refusals (`r02-g21.tick`), geometry finite and bounded
   at the extreme settings, every body on a vertex of its orbit, lighting and banding at the kernel's values, the CPU
   reference, 200 seeded purity snapshots, the committed manifest equal to the Swift one.
3. Simulator: `sim-27` — `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
   ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BinaryGardensExperienceTests`:
   offscreen 1,152 × 768 frames at shown tick 24 of levels 1, 21, 41, 61, 81 at three tiers against the CPU reference
   (world centres +0.15 and star centres +0.4 in luminance over the backdrop, the first actions bar red over blue by
   0.08, the first gauge plate margin 0.05 from the backdrop, the lower-corner 9 × 9 median within 0.06 of the
   gradient), fallback, resize and zero size, memory warning, Reduce Motion stills, failure marks, won bloom, identity.
4. Registration: `packages` — `python3 scripts/check_experience_packages.py`; `catalog-search` — `swift test
   --package-path Packages/VisualCore --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary
   feeds catalog search and stays ≤ 300 characters); `python3 scripts/build_catalog.py --check` last before the record;
   `xcodegen generate` after the `project.yml` edit.
5. Round-two host chunks after the docs: `round02-host-1`, `round02-host-2` (filter
   `'MoonlitMechanism|AcousticConstellator|HarmonicBridges|BinaryGardens'`), `round02-host-3c`, `round02-host-3e`,
   `round02-host-3f` — the baseline commands of step 1.
6. No Stage One breakage: `rendering-27` — `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering
   --scheme VisualCoreRendering-Package --destination sim-27.2 --action test`; `rendering-26` — the same with
   `--destination sim-26.5`; `experiences` — `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative
   --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`; `host-full` — `swift test --package-path
   Packages/VisualCore`; `app-unit` — `python3 scripts/release_check.py --only app-build-for-testing-ios27
   app-unit-ios27` (the candidate opens; the synthetic candidate is `r02-g22.mycelium-architect`).
7. Reference regression (7 of 7 in two chunks): `reference-1` — `python3 scripts/release_check.py --only
   reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`; `reference-2` — `python3
   scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26
   projectm-reference-ios27 projectm-reference-ios26`.
8. Script tests, run alone: `script-tests` — `python3 scripts/test_scripts.py`.
9. Device (after ImplementationLock-100 only): frame time per tier on D1–D3 (`{device}`).
