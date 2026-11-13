# Quickstart: A04-P05 evidence (legacy ledger)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-26.5 --action test
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-j2
python3 scripts/release_check.py --only app-ui-ios27-j3
python3 scripts/release_check.py --only app-ui-ios27-j4
python3 scripts/audit_showcase_dependencies.py --target VisualCore --sources Apps/VisualCore
python3 scripts/check_performance_docs.py
python3 scripts/test_scripts.py
```

Expected: resume ≤ 8 steps and equal digests; monitor rules hold; PROFILE line labelled simulator; budgets row present.
