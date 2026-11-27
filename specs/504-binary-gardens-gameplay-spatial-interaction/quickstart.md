# Quickstart: R02-G21-04

Every check is recorded with `python3 scripts/migration_ledger.py run-check --gate R02-G21-04 --name <name> -- <command>`
(never a scratchpad path; one runner at a time; no source edits while a chain runs; recorded only after every agent has
reported). Names follow feature 494's.

1. Baselines on the committed tree after R02-G21-03 is recorded:
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
   The rendering baseline is R02-G21-03's rendering runs.
2. Host, per Core task (each test < 10 s), all `swift test --package-path Packages/ExperiencesRound02 --filter
   BinaryGardens`:
   - `host-2` — view orbit, orbit camera, preview, ghost star, ghost bands, inspection marks and picker: the picker
     against an independent pick written in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits
     (including 1 and 5 worlds, 2 and 8 rings, tilt 0 and 6, a single luminosity level); the allowances at their
     edges; overlapping targets (a star in front of a world, a pip row over a ring); unusable input; the ring, phase,
     pip, dial and tick targets and the tangent rule; 200 previews equal to the kernel's `changed` and `report` (or
     refusal); every element, ghost and mark inside the view at the orbit corners and 7 aspects 0.4 … 2.5; no preview,
     no inspection and the authored orbit identical to R02-G21-03's geometry; the new materials in the shader sources.
   - `host-3` — gesture controller: 500 seeded scripted taps, star drags (both modes), luminosity and tilt drags,
     world taps and scrubs on playing, won, failed and paused plays at 3 sizes and 3 orbits against an independent
     expectation, every kernel action applied through the adapter; thresholds at their edges; locks and a single
     luminosity level explained; second fingers, cancels and finished plays send no kernel action; orbit, preview,
     inspection and scrubbing change no digest.
   - `host-4` — panel wins: all 100 certified levels won through panel actions alone (each witness action as the
     selected star and its direct ring, phase, luminosity or tilt choice, then Run), in groups so each test is under
     10 s, never more actions than the budget, digests and fingerprints equal to the witness step by step; panel Undo
     then Redo restore the digests.
3. Simulator: `sim-27` — `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
   ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BinaryGardensExperienceTests` —
   pointer wiring: a radial star drag moves it to a ring with the drawn preview, a tangential drag shifts its phase, a
   pip tap and a pip drag set the luminosity, a dial tap and drag set the tilt, a world tap inspects (marks drawn,
   words given) and a second tap clears, a gauge scrub shows ticks, two fingers orbit and a double tap resets (no
   digest change), a refused change (separation or no action left) is previewed as refused, sent once, shown and
   logged with its code, a drag on a won play sends nothing and says the play is over.
4. Round-two host chunks after the docs: `round02-host-1`, `round02-host-2`, `round02-host-3c`, `round02-host-3e`,
   `round02-host-3f` — the baseline commands of step 1.
5. No Stage One breakage: `rendering-27` — `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering
   --scheme VisualCoreRendering-Package --destination sim-27.2 --action test`; `rendering-26` — the same with
   `--destination sim-26.5`; `experiences` — `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative
   --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`; `host-full` — `swift test --package-path
   Packages/VisualCore`; `app-unit` — `python3 scripts/release_check.py --only app-build-for-testing-ios27
   app-unit-ios27`.
6. Reference regression (7 of 7 in two chunks): `reference-1` — `python3 scripts/release_check.py --only
   reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`; `reference-2` — `python3
   scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26
   projectm-reference-ios27 projectm-reference-ios26`.
7. Script tests, run alone: `script-tests` — `python3 scripts/test_scripts.py`.
8. Device (after ImplementationLock-100 only): touch feel and latency on D1–D3 (`{device}`, SC-R02G2104-008).
