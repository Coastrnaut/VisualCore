# Quickstart: A06-P05 evidence (legacy ledger; iOS 27 only)

```bash
swift test --package-path Packages/VisualCore --filter VisualCoreAudioDSPTests
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a06.visualcore-music-lab --runtime 27
python3 scripts/check_public_api.py
python3 scripts/test_scripts.py
```

Expected: all exit 0; the timing test prints the mean per-window cost (asserted < 0.5 ms locally); metrics, palettes,
migrations, presets v2, tier and transition tests pass; the runner passes with the regenerated manifest.
