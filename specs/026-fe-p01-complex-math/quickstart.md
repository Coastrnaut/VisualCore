# Quickstart: validate Fractal Explorer Phase 01

Run every command through `desktop_runbook.py run-check --stage A03-P01`. Run `xcodegen generate` after adding
files.

1. **Host.** Run `swift test --package-path Packages/VisualCore` (PlaneViewportTests) and
   `swift test --package-path Apps/FractalExplorer/FractalExplorerCore`.
2. **App.** Run the `FractalExplorer` scheme on iOS 27.2 and 26.5, then the enumeration guard. Expect the model
   tests, the explorer UI test and the audit to pass.
3. **Checks.** Run the fast checks with `documented-api-fractal-explorer`, `isolation-fractal-explorer`,
   `host-fractal-explorer-core` and `app-contracts`.
4. **ProjectM regression.** Run both chunks; expect 3/3 and 4/4. Then build A01 and A02.
