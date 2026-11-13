# Quickstart: validate UA-F09

Run these from the repository root on `main`. Every command finishes within ten minutes; the driver enforces
its own limits.

## Evidence commands

Record each command with `python3 scripts/migration_ledger.py run-check --gate UA-F09 --name <check-name> --
<command>`. Simulator commands use `--timeout 600`.

| Check name | Command | Expected |
|---|---|---|
| `script-tests` | `python3 scripts/test_scripts.py` | OK (validator, audits, driver units) |
| `self-test` | `python3 scripts/verify_experiences.py --self-test` | PASS; the planted defects are each found |
| `sample-sim` | `python3 scripts/verify_experiences.py --only a99.contract-sample --runtime 27 26` | 9 of 9 scenarios pass on both runtimes; the result bundles pass `xcresulttool`; every record is valid |
| `sample-endurance` | `python3 scripts/verify_experiences.py --only a99.contract-sample --scenario endurance --runtime 27` | pass (the UA-F06 obligation) |
| `debug-sim27`, `debug-sim26` | `python3 scripts/verify_experiences.py --only debug --runtime 27` (and `26`) | 9 of 9 scenarios of the debug experience pass in the app |
| `self-test-sim` | `python3 scripts/verify_experiences.py --self-test --runtime 27` | the fault variant fails save-restore by name; exit 0 of the self-test |
| `audits` | `python3 scripts/verify_experiences.py --audits` | every audit passes on today's sources; entitlement named "not yet provided (UA-F08)" |
| `persistence-host`, `host-visualcore` | `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`, `swift test --package-path Packages/VisualCore` | pass |
| `pure-ios27`, `pure-ios26`, `rendering-ios27`, `rendering-ios26` | the package tests on both runtimes (`xcodebuild_package.py`) | TEST SUCCEEDED |
| `app-<kind>-ios<nn>-<chunk>` | the app test chunks a to f on the phone and the tablet of both runtimes | pass |
| `release-build`, `release-symbols`, `automation-symbols` | Release build; `check_release_symbols.py --app <release> --forbid ScenarioRunner ScenarioLaunch ScenarioManifest VISUALCORE_AUTORUN_EXPERIENCE`; `check_experience_symbols.py --module pure` and `--module host`, with and without `--with-flag` | 0 found without the flag, present with it |
| `public-api`, `documented-api-*`, `dependencies`, `compliance`, `app-isolation`, `privacy-manifest` | the usual checks | pass |
| `build-<Scheme>` | the seven consumer builds | exit 0 |
| `reference-a`, `reference-b` | the two chunks of the ProjectM reference regression | 3 of 3 and 4 of 4 |
| `docs`, `steering` | `python3 scripts/validate_docs.py`, `python3 scripts/validate_autocreator.py` | pass |

When VisualCore changes: `python3 scripts/check_public_api.py --update`, `python3 scripts/check_documented_api.py`,
and the seven-step ProjectM reference regression in two chunks (`reference-a`, `reference-b`).

The brief's commands are `python3 scripts/test_scripts.py`, `python3 scripts/verify_experiences.py --self-test`
and `python3 scripts/verify_experiences.py --only <sample id> --runtime 27 26`, with `<sample id>` =
`a99.contract-sample`.

## Validation scenarios

1. **Manifest**: a complete manifest validates; a missing scenario, an unknown control and an outcome without
   actions are each named.
2. **Outcome**: the sample reaches `target-reached` only by moves; the debug core reaches `taps-counted` after
   three taps; digests are unchanged by the new member.
3. **Runner**: the sample's nine scenarios pass through a real session on both runtimes; `LossySnapshot` fails
   save-restore and `MutatingRejection` fails rejection, each by name.
4. **App**: the debug build started with the request runs the scenario and exits 0; an unknown id exits 2 with a
   record; the Release build has no runner symbol.
5. **Driver**: an interrupted run resumed with `--only` repeats nothing; a scenario that never exits is stopped
   within its limit plus 30 s.
6. **Evidence**: every record validates; each of the invalid kinds is rejected.
7. **Audits**: today's sources pass; a planted TODO, raster file, actionless completion and short game manifest
   each fail.
