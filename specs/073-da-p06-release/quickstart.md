# Quickstart: A09-P06 evidence (legacy ledger; iOS 27 only)

```bash
/bin/sh -c "! grep -rnE 'URLSession|import Network|CLLocation|AVCapture|AVAudio|CMMotion|CNContact|ASIdentifierManager|AppTrackingTransparency|UIScreen.main.brightness|isIdleTimerDisabled' Packages/ExperiencesCreative/DigitalAquarium"
sh specs/073-da-p06-release/scan-realism.sh
python3 scripts/release_check.py --only experience-release-a09 copy-claims-a09
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-q2
python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27
python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
python3 scripts/test_scripts.py
```

Expected: every command exits 0; the sample files behave as specified; the interface tests each finish under 60 s;
owner and device items stay open.
