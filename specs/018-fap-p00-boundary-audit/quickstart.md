# Quickstart: A02-P00 validation

1. `python3 scripts/check_app_contract.py --app fluid-art-playground`: PASS (10 rows, every citation resolves,
   every gap owned).
2. `xcodegen generate --spec project.yml`, then the FluidArtPlayground scheme tests on iOS 27.2 and 26.5: the launch
   smoke test passes, confirmed with `check_test_enumeration.py`.
3. The 7-step reference regression passes and is recorded in `docs/apps/fluid-art-playground/regression-baseline.md`.
4. `git diff --stat <phase-start>..HEAD -- Packages External` is empty.
5. The release-check fast steps (docs, app-contracts, compliance, dependencies) pass.
