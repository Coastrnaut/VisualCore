# Quickstart: A05-P06 evidence (legacy ledger; iOS 27 only)

```bash
/bin/sh -c "! grep -rnE 'URLSession|import Network|CoreMotion|AVFoundation|CoreLocation|AdSupport|AppTrackingTransparency' Packages/ExperiencesCreative/InfiniteGeometry"
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/check_experience_release.py --config docs/apps/infinite-geometry/release.json
python3 scripts/release_check.py --only copy-claims-a05
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-k2
python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 27
python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
python3 scripts/test_scripts.py
```
