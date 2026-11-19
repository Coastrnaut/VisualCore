# Quickstart: A24-P06 (feature 178)

1. `sh specs/178-gbl-p06-release/scan-sources-release.sh` and `sh specs/178-gbl-p06-release/scan-claims-release.sh`:
   both exit 0.
2. `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package
   --destination sim-27.2 --action test --only-testing GraphicsBenchmarkLabCoreTests
   GraphicsBenchmarkLabExperienceTests`: the recovery and sample tests pass.
3. `xcodegen generate --spec project.yml`, then
   `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-f3`.
4. Release checks: `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest
   app-no-tracking app-licenses app-usage-descriptions experience-release-a24 copy-claims-a24` (the A23-P06 set).
5. `python3 scripts/check_app_contract.py --app graphics-benchmark-lab --render`: all 12 gaps are closed.
