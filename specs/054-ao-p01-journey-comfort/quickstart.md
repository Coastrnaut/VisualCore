# Quickstart: A07-P01 evidence (legacy ledger; iOS 27 only)

```bash
swift test --package-path Packages/VisualCore --filter "CameraRailTests|RailFlightTests|OriginRebaseTests"
swift test --package-path Packages/ExperiencesCreative --filter "JourneyStateTests|JourneyRailTests|WorldPiecesTests"
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AudioOdysseyExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a07.audio-odyssey --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_public_api.py
python3 scripts/test_scripts.py
```

Expected: all pass; nine standard and two fixture scenarios pass; the API baseline lists the new types.
