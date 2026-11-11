# Quickstart: validate Fluid Art Playground Phase 05

Run each command through `desktop_runbook.py run-check --stage A02-P05`, with one runtime per call. Run
`xcodegen generate` after adding files. Clear stale `Build/DerivedData/<App>` after VisualCore API changes.

1. **Host.** Run `swift test --package-path Packages/VisualCore` (SyntheticGestureScriptTests) and
   `swift test --package-path Apps/FluidArtPlayground/FluidArtPlaygroundCore` (FluidDetailTests,
   SimulationControlTests).
2. **VisualCoreRendering package.** Run `scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme
   VisualCoreRendering-Package --destination sim-27.2|sim-26.5 --action test`. Expect the automation seed and check
   tests to pass.
3. **App.** Run the `FluidArtPlayground` scheme on iOS 27.2 and 26.5, then the enumeration guard. Expect controls,
   determinism, fixture suite, stress, detail and automation tests to pass, plus the controls UI test and the audit.
4. **Automation rehearsal (simulator only).** Install the Debug app on the 27.2 simulator. For smoke, launch and
   lifecycle, run
   `xcrun simctl launch --terminate-running-process <udid> dev.visualcore.FluidArtPlayground` with
   `SIMCTL_CHILD_VISUALCORE_AUTORUN=<mode>` and `SIMCTL_CHILD_VISUALCORE_AUTORUN_SEED=7`. Copy the report out of the
   data container and expect result "pass" with a digest. This is not device evidence.
5. **Release symbols.** Run `xcodebuild build -scheme FluidArtPlayground -configuration Release -destination
   generic/platform=iOS CODE_SIGNING_ALLOWED=NO`, then `check_release_symbols.py --app <app>`. Expect 0.
6. **Checks.** Run `release_check.py --only docs app-contracts compliance dependencies public-api licenses
   script-tests host-visualcore documented-api-fluid-art-playground isolation-fluid-art-playground
   host-fluid-art-playground-core`.
7. **ProjectM regression.** Both chunks, 3/3 + 4/4. Also build A01 to check that it compiles against the changed
   packages.
