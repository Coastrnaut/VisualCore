# Quickstart: A24-P00 evidence (legacy ledger)

```bash
python3 scripts/check_app_contract.py --app graphics-benchmark-lab --render
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
python3 scripts/release_check.py --only app-build-for-testing-ios27
python3 scripts/check_experience_packages.py
git diff --stat 7de0f2af..HEAD -- Packages External
python3 scripts/test_scripts.py
python3 scripts/release_check.py --only docs app-contracts compliance dependencies
```

Expected: the contract passes; 7 of 7 reference steps pass; the app builds; there are 23 experiences, none of them
A24; the diff is empty; the script tests and document steps pass.
