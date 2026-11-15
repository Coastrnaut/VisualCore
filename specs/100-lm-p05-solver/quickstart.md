# Quickstart: A13-P05 (feature 100)

1. Light Maze tests on iOS 27:
   `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests`
   — expect SolverTests (20 levels solved with fewest turns equal to the recorded ones; unsolvable and refused
   fixtures; 16-tile board searched, 17 refused), ContentQATests (20 pass; damaged fixtures fail with their check;
   committed `content-qa.md` matches) and MazeBeamFixtureTests (60 boards) to pass.
2. Regenerate `docs/apps/light-maze/content-qa.md`: prefix the command with
   `UPDATE_CONTENT_QA=1 TEST_RUNNER_UPDATE_CONTENT_QA=1`.
3. Contract: `python3 scripts/check_app_contract.py --app light-maze --render` — G-SOLVER closed.
4. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner:
   `python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27`.
5. Packages and scripts: `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`.
