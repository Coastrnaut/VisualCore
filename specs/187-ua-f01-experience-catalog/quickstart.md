# Quickstart: validate UA-F01

Run from the repository root on `main`. Every command finishes within ten minutes.

## Prerequisites

- `python3 scripts/verify_environment.py` prints `PASS`; `python3 scripts/migration_ledger.py show --gate UA-F01`
  prints `UNMET: none`.
- The prebuilt ANGLE frameworks exist (`External/projectm-ios/Build/ANGLEFrameworks`), as for every framework gate.

## Evidence commands

Each is recorded with `python3 scripts/migration_ledger.py run-check --gate UA-F01 --name <check-name> --
<command>` (simulator and reference commands with `--timeout 600`).

| Check name | Command | Expected |
|---|---|---|
| `host-experience` | `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests` | all tests pass |
| `host-visualcore` | `swift test --package-path Packages/VisualCore` | the whole package passes |
| `catalog-check` | `python3 scripts/build_catalog.py --check` | `PASS: runtime catalog, 0 problems` |
| `public-api` | `python3 scripts/check_public_api.py` | pass after `python3 scripts/check_public_api.py --update` was committed |
| `documented-api` | `python3 scripts/check_documented_api.py --sources Showcase/App` (and the two harnesses) | pass |
| `dependencies` | `python3 scripts/check_dependencies.py` | pass: the new module is pure |
| `sim-ios27`, `sim-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` and `--destination sim-26.5` | `TEST SUCCEEDED` on both runtimes |
| `reference-a` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | 3 of 3 |
| `reference-b` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | 4 of 4 |
| `script-tests`, `docs`, `steering` | `python3 scripts/test_scripts.py`, `python3 scripts/validate_docs.py`, `python3 scripts/validate_autocreator.py` | pass |

## Validation scenarios

1. **Identity (US1)**: the identity tests pass; `python3 scripts/build_catalog.py --check` passes; editing one id
   in a scratch copy of the golden list makes the check fail naming it.
2. **Allocation (US2)**: `python3 scripts/build_catalog.py` prints `100 experiences, 50 free, 50 premium, 0
   available`; the allocation tests refuse four wrong manifests.
3. **Safe loading (US3)**: the damaged-fixture tests pass, one typed error per fixture.
4. **Availability (US4)**: the script tests build from a temporary ledger with `X-A01` forced to pass and find
   exactly one available entry; with the real ledger, none.
5. **Categories and search (US5)**: the category counts are 5, 4, 4, 4, 4, 4, 75; the search table gives the same
   results under two language settings.
6. **Registry (US6)**: the registry tests pass for the five cases.
7. **Framework obligations**: API baseline updated and checked; package tests on both simulators; reference
   regression 7 of 7 in two chunks; the consumers build for testing.

Details: [contracts/visualcore-experience-api.md](contracts/visualcore-experience-api.md),
[contracts/catalog-files.md](contracts/catalog-files.md), [data-model.md](data-model.md).
