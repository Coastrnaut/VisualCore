# Quickstart: A14-P06 (feature 108)

1. `sh specs/108-sse-p06-release/scan-sources-release.sh`; `sh specs/108-sse-p06-release/scan-claims-release.sh`.
2. `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests`.
3. `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-v2`.
4. `python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`.
5. `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a14 copy-claims-a14`; `python3 scripts/test_scripts.py`.
