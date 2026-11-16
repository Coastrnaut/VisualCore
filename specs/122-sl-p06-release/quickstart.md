# Quickstart: A16-P06 (feature 122)

1. `sh specs/122-sl-p06-release/scan-sources-release.sh`; `sh specs/122-sl-p06-release/scan-claims-release.sh`.
2. Package suites: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SimulationLabCoreTests SimulationLabExperienceTests`.
3. `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-x2`; `python3 scripts/verify_experiences.py --only a16.simulation-lab --runtime 27`.
4. `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a16 copy-claims-a16`; `python3 scripts/test_scripts.py`.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A16-P06 --timeout 600 --name <n> -- <command>`.
