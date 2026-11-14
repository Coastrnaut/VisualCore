# Quickstart: A06-P06 evidence (legacy ledger; iOS 27 only)

```bash
/bin/sh -c "! grep -rnE 'URLSession|import Network|CoreMotion|CoreLocation|AVAudioRecorder|AVAssetWriter' Packages/ExperiencesCreative/VisualCoreMusicLab Packages/VisualCoreRendering/Sources/VisualCoreAudio"
python3 scripts/release_check.py --only experience-release-a06 copy-claims-a06
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-m2
python3 scripts/verify_experiences.py --only a06.visualcore-music-lab --runtime 27
python3 scripts/release_check.py --only app-release-build app-release-symbols app-release-privacy-manifest
python3 scripts/test_scripts.py
```

Expected: all exit 0; the scan finds nothing; documents and copy pass; fixtures and recovery tests pass; chunk m2 passes
with each test < 60 s; release checks pass.
