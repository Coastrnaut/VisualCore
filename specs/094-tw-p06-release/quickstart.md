# Quickstart: A12-P06 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing TinyWorldsCoreTests TinyWorldsExperienceTests
xcodegen generate --spec project.yml
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-t2
python3 scripts/verify_experiences.py --only a12.tiny-worlds --runtime 27
python3 scripts/release_check.py --only experience-release-a12 copy-claims-a12
sh specs/094-tw-p06-release/scan-claims-release.sh
python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
python3 scripts/test_scripts.py
```

Expected: all pass; interface tests each under 60 s; owner and device rows open.
