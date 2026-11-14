# Quickstart: A07-P06 evidence (legacy ledger; iOS 27 only)

```bash
/bin/sh -c "! grep -rnE 'URLSession|import Network|CoreMotion|CoreLocation|AVAudioRecorder|AVAssetWriter' Packages/ExperiencesCreative/AudioOdyssey Packages/VisualCoreRendering/Sources/VisualCoreAudio"
python3 scripts/release_check.py --only experience-release-a07 copy-claims-a07
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-o2
python3 scripts/verify_experiences.py --only a07.audio-odyssey --runtime 27
python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
python3 scripts/test_scripts.py
```

Expected: all exit 0; the scan finds nothing; documents and copy pass; fixtures and recovery tests pass; chunk o2 passes
with each test < 60 s; release checks pass.
