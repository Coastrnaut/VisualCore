# Quickstart: validate Fluid Art Playground Phase 04

Run each command through `desktop_runbook.py run-check --stage A02-P04`.

1. **Host.** `swift test --package-path Apps/FluidArtPlayground/FluidArtPlaygroundCore` (palette definitions,
   configuration).
2. **Rendering package**, iOS 27.2 and 26.5. Expected: FieldPassTests passes, including the observer test.
3. **App** (`xcodegen generate` first), iOS 27.2 and 26.5, then the guard. Expected: palette renders, pinch, capture,
   pass isolation and the UI tests pass.
4. **Checks.** Release fast steps, `check_app_isolation --app Apps/FluidArtPlayground --built-app <app> --allow-usage
   NSPhotoLibraryAddUsageDescription`, and the contract.
5. **ProjectM regression** (3/3 + 4/4), then an A01 build.
