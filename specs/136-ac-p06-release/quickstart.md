# Quickstart: A18-P06 (feature 136)

1. `sh specs/136-ac-p06-release/scan-sources-release.sh`; `sh specs/136-ac-p06-release/scan-claims-release.sh`.
2. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AmbientClockCoreTests AmbientClockExperienceTests`.
3. `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-z2`; `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a18 copy-claims-a18`.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A18-P06 --timeout 600 --name <n> -- <command>`.
