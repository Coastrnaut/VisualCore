# Quickstart: A10-P03 evidence (legacy ledger; iOS 27 only)

```bash
swift test --package-path Packages/VisualCore --filter SoundEffectSynthTests
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreAudioTests/SoundEffectPlayerTests
python3 scripts/check_public_api.py
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing NeonArcadeCoreTests NeonArcadeExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a10.neon-arcade --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app neon-arcade --render
python3 scripts/test_scripts.py
```

Expected: all pass; fixtures 1–14; the contract records G-SOUNDFX and G-TRANSITIONS closed by A10-P03.
