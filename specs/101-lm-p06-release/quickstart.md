# Quickstart: A13-P06 (feature 101)

1. Source scan and claims: `specs/101-lm-p06-release/scan-claims-release.sh` and the no-network grep (tasks.md).
2. Package tests: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests`.
3. App and interface: `xcodegen generate --spec project.yml`, then `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-u2`.
4. Runner: `python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27`.
5. Release checks: `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a13 copy-claims-a13`.
6. Script tests: `python3 scripts/test_scripts.py`.
