# Quickstart: validate UA-F02

Run from the repository root on `main`. Every command finishes within ten minutes.

## Prerequisites

- `python3 scripts/verify_environment.py` prints `PASS`; `python3 scripts/migration_ledger.py show --gate UA-F02`
  prints `UNMET: none`.
- The prebuilt ANGLE frameworks exist (`External/projectm-ios/Build/ANGLEFrameworks`), as for every framework gate.

## Evidence commands

Each is recorded with `python3 scripts/migration_ledger.py run-check --gate UA-F02 --name <check-name> --
<command>` (simulator, symbol and reference commands with `--timeout 600`).

| Check name | Command | Expected |
|---|---|---|
| `host-experience` | `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests` | all tests pass |
| `host-visualcore` | `swift test --package-path Packages/VisualCore` | the whole package passes |
| `rendering-ios27` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f02-ios27` | `TEST SUCCEEDED`, including `VisualCoreExperienceHostTests` |
| `rendering-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test --result-name ua-f02-ios26` | `TEST SUCCEEDED`, including `VisualCoreExperienceHostTests` |
| `pure-ios27`, `pure-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` and `--destination sim-26.5` | `TEST SUCCEEDED` on both runtimes (the committed digests match) |
| `symbols-pure`, `symbols-pure-flag` | `python3 scripts/check_experience_symbols.py --module pure` and `--module pure --with-flag` | 0 automation symbols without the flag; at least 1 with it |
| `symbols-host`, `symbols-host-flag` | `python3 scripts/check_experience_symbols.py --module host` and `--module host --with-flag` | 0 automation symbols without the flag; at least 1 with it |
| `public-api` | `python3 scripts/check_public_api.py` | pass after `python3 scripts/check_public_api.py --update` was committed |
| `documented-api` | `python3 scripts/check_documented_api.py --sources Showcase/App` (and the two harnesses) | pass |
| `dependencies` | `python3 scripts/check_dependencies.py` | pass: the pure module stays pure, the sample is used by tests only |
| `reference-a` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | 3 of 3 |
| `reference-b` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | 4 of 4 |
| `script-tests`, `docs`, `steering` | `python3 scripts/test_scripts.py`, `python3 scripts/validate_docs.py`, `python3 scripts/validate_autocreator.py` | pass |

## Validation scenarios

1. **Lifecycle (US1)**: the lifecycle tests try all 64 state pairs and all 96 operation cells and find 20 and 28
   legal ones.
2. **Determinism (US2)**: 256 seeds prepare twice to equal digests; eight committed digests match on the host and
   on both simulators; four frame patterns give the same step count and digest; a cancelled preparation ends in
   inactive within one second.
3. **Snapshots (US3)**: 100 round trips; a version-1 snapshot migrates to its committed digest; one fixture per
   refusal; a snapshot is stored and loaded through the document store.
4. **Input (US4)**: the action table produces every rejection code; a replay of 200 actions reproduces the digest.
5. **Rendering (US5)**: on both simulators the sample draws the colour of its state, survives a context
   recreation, keeps its digest through tier changes and cache shedding, and leaves 0 live and 0 leaked GPU
   objects after deactivation.
6. **Diagnostics and automation (US6)**: diagnostics are complete in all eight states; the four symbol checks
   pass; a scenario of 100 steps and 10 actions reports the committed digest.
7. **Conformance (US7)**: the sample passes all seven checks; each of the seven faults fails exactly its own
   check; the run takes less than ten seconds.
8. **Framework obligations**: API baseline updated and checked; documentation of every public symbol; package
   tests on both simulators; reference regression 7 of 7 in two chunks; the consumers build for testing.

Details: [contracts/experience-core-api.md](contracts/experience-core-api.md),
[contracts/experience-host-api.md](contracts/experience-host-api.md), [data-model.md](data-model.md).
