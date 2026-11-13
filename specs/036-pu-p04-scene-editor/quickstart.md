# Quickstart: A04-P04 evidence (legacy ledger)

Record each with `python3 Tools/python/desktop_runbook.py run-check --stage A04-P04 --name <check> -- <command>`.

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-26.5 --action test
python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone --only-testing VisualCoreUITests/PUSceneLibraryUITests --sources Apps/VisualCore/Tests/UI
python3 scripts/check_compliance.py
python3 scripts/test_scripts.py
```

Expected: SceneDocument v1/v2 round trips; 4 bad files refused; open sequence replays to the same digest; move kept
after save; 7 force kinds finite for 600 steps; UI test saves, reopens after relaunch, renames and deletes.
