# Quickstart: A18-P02 (feature 132)

1. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AmbientClockCoreTests AmbientClockExperienceTests`.
2. Catalog (`python3 scripts/build_catalog.py --check`), app build and unit (`xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`), runner (`python3 scripts/verify_experiences.py --only a18.ambient-clock --runtime 27`).
3. Documented API, contract, packages and script tests.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A18-P02 --timeout 600 --name <n> -- <command>`.
