# Quickstart: A01-P06 validation

1. `python3 scripts/test_scripts.py`: the privacy-scan and release-check cases pass, including their failing
   fixtures.
2. `swift test --package-path Apps/GenerativeArtStudio/Core`: `LibraryMigrationFixtureTests` loads 4 v1 files with 0
   problems.
3. GenerativeArtStudio scheme on iOS 27.2 and 26.5, with the full suites enumeration-guarded:
   `IconRenderTests`, `CrashRecoveryTests` and every earlier test.
4. VisualCoreRendering package tests (including `AutomationView`) on both runtimes; the reference regression (7
   steps); the Showcase suite on both runtimes.
5. Automation rehearsal on both runtimes:
   `python3 scripts/run_automation_sim.py --app <Debug GenerativeArtStudio.app> --runtime 27.2 --mode smoke --out <dir>`
   (and `launch`, `lifecycle`, and 26.5).
6. Release build (generic iOS, unsigned), then on the built app: `check_release_symbols.py`,
   `check_privacy_manifest.py` and `check_app_release.py --config docs/apps/generative-art-studio/release.json`.
7. `check_app_contract.py`, the documented API check and the release-check fast steps.
