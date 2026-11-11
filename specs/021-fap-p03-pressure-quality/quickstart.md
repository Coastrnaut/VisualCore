# Quickstart: validate Fluid Art Playground Phase 03

Run each command through `desktop_runbook.py run-check --stage A02-P03`, one runtime per call. Run
`xcodegen generate` after adding files, and clear stale `Build/DerivedData/<App>` after VisualCore API changes.

1. **Host.** `swift test --package-path Packages/VisualCore` (QualityPolicyTests) and `swift test --package-path
   Apps/FluidArtPlayground/FluidArtPlaygroundCore` (FluidSolverTests, FluidQualityTests).
2. **App.** Run the `FluidArtPlayground` scheme on iOS 27.2 and 26.5, then the enumeration guard. Expected: the
   projection, boundary and quality wiring fixtures, the Adjust UI test and the audit all pass, with every earlier
   fixture still green.
3. **Checks.** `release_check.py --only docs app-contracts compliance dependencies public-api licenses script-tests
   documented-api-fluid-art-playground isolation-fluid-art-playground host-fluid-art-playground-core
   host-visualcore`.
4. **Contract.** `check_app_contract.py --app fluid-art-playground --render`.
5. **ProjectM regression.** Both chunks, 3/3 + 4/4. Also build A01 to check that it still compiles against the
   changed packages.
