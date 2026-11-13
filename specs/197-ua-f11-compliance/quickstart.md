# Quickstart: UA-F11 evidence

Prerequisites: UA-F04 and UA-F10 pass; real ANGLE frameworks built in the reference submodule; the Release app built
by the release check (`APP=Build/DerivedData/release-VisualCore-Release-sim/Build/Products/Release-iphonesimulator/VisualCore.app`,
the path the `app-release-build` step uses). Record each command with
`python3 scripts/migration_ledger.py run-check --gate UA-F11 --name <check> -- <command>`.

## Required evidence commands

```bash
python3 scripts/check_privacy_manifest.py --app "$APP" --json .autonomy/logs/ua-f11/privacy.json   # PASS, 0 undeclared/unused
python3 scripts/check_licenses.py                                                                   # PASS
python3 scripts/check_licenses.py --app "$APP"                                                      # PASS, bundled == shipped
python3 scripts/check_compliance.py                                                                 # PASS, incl. tracking rule
python3 scripts/check_release_symbols.py --app "$APP"                                               # PASS
python3 scripts/check_no_tracking.py --app "$APP" --json .autonomy/logs/ua-f11/tracking.json        # PASS, 0 findings
python3 scripts/check_usage_descriptions.py --app "$APP"                                            # PASS, 1 key
python3 scripts/audit_showcase_dependencies.py --target VisualCore --sources Apps/VisualCore --app "$APP"   # PASS, no ProjectM
python3 scripts/check_distinctiveness.py --check                                                    # PASS, 4950 pairs, 0 shared
python3 scripts/metadata_inputs.py --check                                                          # PASS, 3 experiences
python3 scripts/build_catalog.py --check                                                            # PASS
```

## Self-tests (planted defects)

```bash
python3 scripts/test_scripts.py          # includes scripts/tests/test_{no_tracking,compliance_tracking,usage_descriptions,licenses_app,privacy_report,distinctiveness,metadata_inputs,report_meta}.py
```

## App interface test (iOS 27.x phone, one pass)

```bash
python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone --only-testing VisualCoreUITests/AcknowledgementsUITests --sources Apps/VisualCore/Tests/UI
```

## Release check and CI

```bash
python3 scripts/release_check.py --only compliance licenses usage-descriptions distinctiveness metadata-inputs
python3 scripts/release_check.py --only app-release-build app-privacy-manifest app-release-symbols app-no-tracking app-licenses app-usage-descriptions
gh run list --workflow ci --limit 1      # the commit with all UA-F11 changes: success
```

## Documents and timing

```bash
python3 scripts/validate_autocreator.py && python3 scripts/validate_docs.py && python3 scripts/migration_baseline.py verify
```
Each check above prints its elapsed time; every one must be under 60 s (SC-U11-008).

## Only when VisualCore changes (not expected; research D10)

```bash
python3 scripts/check_public_api.py --update
python3 scripts/check_documented_api.py
# seven-step ProjectM reference regression, two chunks (Auto-Creator.md §19)
```
