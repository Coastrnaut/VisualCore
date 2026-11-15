# Quickstart: A13-P04 (feature 099)

1. Light Maze tests on iOS 27:
   `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests`
   — expect HintTests (following hints solves all 20 levels), BoardDescriptionTests (fixtures named fully; largest
   board ≤ 4,000 characters), SuccessCueTests, MazeHintTests, MazeFeedbackTests (one cue per solve; Reduce Motion and
   Reduce Flashing), MazeStyleTests (no sign problems; contrasts ≥ 3 : 1) to pass.
2. Regenerate the manifest after adding the hint fixture: prefix the command with
   `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`.
3. Contract: `python3 scripts/check_app_contract.py --app light-maze --render` — G-FEEDBACK closed.
4. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner:
   `python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27`.
5. Packages and scripts: `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`.
