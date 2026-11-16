# Quickstart: A15-P06 (feature 115)

1. Scans: `sh specs/115-me-p06-release/scan-sources-release.sh`; `sh specs/115-me-p06-release/scan-claims-release.sh`.
2. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests`.
3. App: `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-w2`; runner `python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`.
4. Release: `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a15 copy-claims-a15`.
5. `python3 scripts/test_scripts.py`.
