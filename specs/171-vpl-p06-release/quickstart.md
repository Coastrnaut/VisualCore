# Quickstart: A23-P06 (feature 171)

1. `sh specs/171-vpl-p06-release/scan-sources-release.sh` and `sh specs/171-vpl-p06-release/scan-claims-release.sh`:
   both exit 0.
2. `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package
   --destination sim-27.2 --action test --only-testing VisualProgrammingLabCoreTests
   VisualProgrammingLabExperienceTests`: the recovery and sample tests pass.
3. `xcodegen generate --spec project.yml`, then
   `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-e3`.
4. Release checks: `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest
   app-no-tracking app-licenses app-usage-descriptions experience-release-a23 copy-claims-a23` (the A22-P06 set).
5. `python3 scripts/check_app_contract.py --app visual-programming-lab --render`: all 9 gaps are closed.
