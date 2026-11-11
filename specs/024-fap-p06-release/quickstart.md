# Quickstart: validate Fluid Art Playground Phase 06

Run each command through `desktop_runbook.py run-check --stage A02-P06`, one runtime per call. Run `xcodegen
generate` after adding files. Clear stale `Build/DerivedData/<App>` after VisualCore API changes.

1. **Host.** `swift test --package-path Packages/VisualCore` (TemporaryFolderTests), then `check_public_api.py`.
2. **App.** Run the `FluidArtPlayground` scheme on iOS 27.2 and 26.5, then the enumeration guard. Expected:
   - icon provenance, crash recovery, privacy, Acknowledgements UI and the audit all pass;
   - every earlier test is still green.
3. **Release.** `release_check.py --only app-release-fluid-art-playground` (unsigned Release build, symbols 0,
   privacy scan 0/0, release check all items). Then `check_app_isolation.py` with the built app.
4. **Checks.** The fast checks, `check_app_contract.py --app fluid-art-playground --render` and `check_licenses.py`.
5. **ProjectM regression.** Both chunks, 3/3 + 4/4. Build A01 to check that it compiles against the changed
   packages.
