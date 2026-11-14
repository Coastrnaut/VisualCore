# Quickstart: A09-P00 evidence (legacy ledger)

```bash
python3 scripts/check_app_contract.py --app digital-aquarium --render
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
python3 scripts/release_check.py --only app-build-for-testing-ios27
python3 scripts/check_experience_packages.py
git diff --stat 951802c1..HEAD -- Packages External
python3 scripts/test_scripts.py
```

Expected: contract PASS; 7 of 7 reference steps; the app builds; 8 experiences, none A09; empty diff; script tests OK.
