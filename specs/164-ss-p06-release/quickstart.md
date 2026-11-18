# Quickstart: A22-P06 (feature 164)

1. `sh specs/164-ss-p06-release/scan-sources-release.sh` and `sh specs/164-ss-p06-release/scan-claims-release.sh`:
   both exit 0.
2. Shader Studio tests (the package command of A22-P05): the recovery and sample tests pass.
3. `xcodegen generate --spec project.yml`, then
   `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-d3`.
4. Release checks: `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest
   app-no-tracking app-licenses app-usage-descriptions experience-release-a22 copy-claims-a22` (the A21-P06 set).
5. `python3 scripts/check_app_contract.py --app shader-studio --render`: all 13 gaps are closed.
