# Quickstart: A06-P04 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreAudioTests
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a06.visualcore-music-lab --runtime 27
python3 scripts/check_audio_hot_path.py
python3 scripts/check_public_api.py
python3 scripts/test_scripts.py
```

Expected: all exit 0; event mapping table, monitor and 50 seeded recovery sequences pass; preset library, apply,
status and denied-usability tests pass; the runner passes with the regenerated manifest; the hot path stays clean.
