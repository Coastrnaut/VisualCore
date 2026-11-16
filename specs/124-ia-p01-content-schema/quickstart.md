# Quickstart: A17-P01 (feature 124)

1. Core tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing InteractiveAnatomyCoreTests`.
2. Contract `python3 scripts/check_app_contract.py --app interactive-anatomy --render`; `python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/InteractiveAnatomy`; `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`; app `python3 scripts/release_check.py --only app-build-for-testing-ios27`.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A17-P01 --timeout 600 --name <n> -- <command>`.
