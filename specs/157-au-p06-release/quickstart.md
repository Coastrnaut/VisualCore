# Quickstart: A21-P06 (feature 157)

1. `sh specs/157-au-p06-release/scan-sources-release.sh`; `sh specs/157-au-p06-release/scan-claims-release.sh`.
2. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AuroraCoreTests AuroraExperienceTests`.
3. `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-c3`; `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a21 copy-claims-a21`.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A21-P06 --timeout 595 --name <n> -- <command>`.
