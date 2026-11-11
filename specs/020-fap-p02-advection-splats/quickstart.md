# Quickstart: validate Fluid Art Playground Phase 02

Every command is wrapped in `python3 Tools/python/desktop_runbook.py run-check --stage A02-P02 --name <n> --timeout
<s> -- …`, one runtime per call.

1. **Host**. Expected: tracker, bilinear, splat, queue and advection suites pass.
   - `swift test --package-path Packages/VisualCore`
   - `swift test --package-path Apps/FluidArtPlayground/FluidArtPlaygroundCore`
2. **Rendering package**. Expected: FieldBilinearTests pass; the enumeration guard covers every declared test.
   - `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name <n>`
   - then the same with `sim-26.5`.
3. **App**. Run `xcodegen generate --spec project.yml` (always, after adding files), then the `FluidArtPlayground`
   scheme test on `19108E51-…` (27.2) and `EC7498FF-…` (26.5), then
   `check_test_enumeration.py --sources Apps/FluidArtPlayground/Tests --log <log>`. Expected: the zero-velocity,
   uniform-advection and splat fixtures plus the UI splash test pass.
4. **Checks**. Expected: pass.
   - `check_public_api.py` (`--update` after the review)
   - `release_check.py --only docs app-contracts compliance dependencies public-api licenses script-tests documented-api-fluid-art-playground isolation-fluid-art-playground host-fluid-art-playground-core`
   - `check_app_contract.py --app fluid-art-playground --render`
5. **ProjectM regression**: the two `release_check.py --only reference-…` chunks. Expected: 3/3 + 4/4.
