# Quickstart: A01-P00 validation

1. `python3 scripts/check_app_contract.py --app generative-art-studio` → PASS (10 matrix rows, every citation resolves,
   decision go).
2. `python3 scripts/test_scripts.py` → OK, including AppContractTests: the good fixture passes; the bad fixture
   reports a missing file, a missing symbol, a non-public evidence item, an unknown product and an uncovered gap.
3. `xcodegen generate --spec project.yml`, then run the `GenerativeArtStudio` scheme's tests on the iOS 27.2 and 26.5
   simulators → the launch smoke test passes.
4. `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim
   reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 reference-clean projectm-reference-ios27
   projectm-reference-ios26` → all pass; results recorded in `docs/apps/generative-art-studio/regression-baseline.md`.
5. `git diff --stat <phase-start>..HEAD -- Packages External` → empty (no VisualCore or ProjectM changes).

Contract: [contracts/app-contract.md](contracts/app-contract.md) · data: [data-model.md](data-model.md).
