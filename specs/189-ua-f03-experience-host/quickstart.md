# Quickstart: validate UA-F03

Run from the repository root on `main`. Every command finishes within ten minutes.

## Prerequisites

- `python3 scripts/verify_environment.py` prints `PASS`; `python3 scripts/migration_ledger.py show --gate UA-F03`
  prints `UNMET: none`.
- The prebuilt ANGLE frameworks exist (`External/projectm-ios/Build/ANGLEFrameworks`).

## Evidence commands

Each is recorded with `python3 scripts/migration_ledger.py run-check --gate UA-F03 --name <check-name> --
<command>` (simulator and reference commands with `--timeout 600`).

| Check name | Command | Expected |
|---|---|---|
| `rendering-ios27` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f03-ios27` | `TEST SUCCEEDED`, including the session tests |
| `rendering-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test --result-name ua-f03-ios26` | `TEST SUCCEEDED`, including the session tests |
| `app-isolation` | `python3 scripts/check_app_isolation.py --app Apps/VisualCore` | exit 0; until UA-F04 creates the app: `nothing checked (no Swift sources yet)` |
| `experience-isolation` | `python3 scripts/check_app_isolation.py --experiences Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost Packages/VisualCore/Sources/VisualCoreExperience` | PASS, 0 problems |
| `host-visualcore` | `swift test --package-path Packages/VisualCore` | the whole package passes |
| `pure-ios27`, `pure-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` and `--destination sim-26.5` | `TEST SUCCEEDED` |
| `public-api` | `python3 scripts/check_public_api.py` | pass after `--update` was committed |
| `documented-api-showcase`, `-interactivedemo`, `-secondconsumer` | `python3 scripts/check_documented_api.py --sources <consumer sources>` | pass |
| `dependencies` | `python3 scripts/check_dependencies.py` | pass |
| `reference-a` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` | 3 of 3 |
| `reference-b` | `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | 4 of 4 |
| `script-tests`, `docs`, `steering` | `python3 scripts/test_scripts.py`, `python3 scripts/validate_docs.py`, `python3 scripts/validate_autocreator.py` | pass |

## Validation scenarios

1. **Open (US1)**: the sample opens to running with a picture and four stage timings; the three failure kinds and
   the timeout end in failed with Retry and Back working.
2. **One at a time (US2)**: 50 cycles with zero live and leaked objects; a second open closes the first before it
   prepares; `hostsAlive` is never above 1.
3. **Cancellation (US3)**: a close during preparation ends in idle within a second, 20 of 20 times.
4. **Phases (US4)**: background and inactive suspend, active resumes with no catch-up; a snapshot per suspension.
5. **Memory and context (US5)**: shedding below the limit, closure with a message above it, context recreation
   with an equal digest and picture.
6. **Isolation (US6)**: the tool passes on the repository, fails on two scratch violations, and reports "nothing
   checked" for an empty folder.
7. **Framework obligations**: API baseline, documentation, both runtimes, reference regression 7 of 7.

Details: [contracts/session-api.md](contracts/session-api.md), [data-model.md](data-model.md).
