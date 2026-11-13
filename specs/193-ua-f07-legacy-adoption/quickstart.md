# Quickstart: validate UA-F07

Run these from the repository root on `main`. Every command finishes within ten minutes. Record evidence with
`python3 scripts/migration_ledger.py run-check --gate UA-F07 --name <check-name> -- <command>`; X-A01 to X-A03 use
their own gates.

| Check name | Command | Expected |
|---|---|---|
| `core-a01` … `core-a04` | `swift test --package-path Apps/GenerativeArtStudio/Core`, `swift test --package-path Apps/FluidArtPlayground/FluidArtPlaygroundCore`, `swift test --package-path Apps/FractalExplorer/FractalExplorerCore`, `swift test --package-path Apps/ParticleUniverse/ParticleUniverseCore` (after the move: `swift test --package-path Packages/ExperiencesCreative --filter <Name>CoreTests`) | the same tests pass, none changed |
| `fixtures` | `python3 scripts/migration_baseline.py verify` | the six fixture hashes equal the baseline |
| `verify-a01-a03` | `python3 scripts/verify_experiences.py --only a01.generative-art-studio a02.fluid-art-playground a03.fractal-explorer --runtime 27 26` | every scenario passes on both runtimes |
| `verify-a04` | `python3 scripts/verify_experiences.py --only a04.particle-universe --runtime 27 26` | every scenario passes (X-A04 still pending) |
| `test-map` | `python3 scripts/check_test_map.py --map specs/193-ua-f07-legacy-adoption/test-map.csv …` | 56 of 56 old tests mapped; every new test exists and passed |
| `app-<kind>-ios<nn>-<chunk>` | the app test chunks a to f plus the four ported classes' chunks, on the phone and the tablet of both runtimes | pass |
| `reference-b` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | 4 of 4 |
| `reference-a` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | 3 of 3 |
| `public-api`, `documented-api-*`, `dependencies`, `compliance`, `app-isolation`, `release-symbols`, `privacy-manifest` | the usual checks | pass |
| `legacy-ledger` | `shasum -a 256 .autonomy/state.json` compared with its value before the feature | equal |

When VisualCore changes: `python3 scripts/check_public_api.py --update`, `python3 scripts/check_documented_api.py`,
and the seven-step ProjectM reference regression in two chunks.

## Validation scenarios

1. **A01**: the launcher with `-vcCandidates` shows Generative Art Studio; a preset, a seed and a save work; the
   app ends and the composition comes back.
2. **A03**: a drag pans; a pinch zooms; a tour advances with steps.
3. **A04**: a tap places the force at the tapped point; the same seed and actions give the standalone checksum.
4. **A02**: a stroke paints; after the app ends the configuration is restored and the fluid restarts from the seed.
5. **Moves**: each move is in `Catalog/path-map.json`; the tests pass again; the target is gone and the project
   builds.
