# Quickstart: A04-P06 evidence (legacy ledger)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-26.5 --action test
python3 scripts/check_experience_release.py --config docs/apps/particle-universe/release.json
python3 scripts/check_copy_claims.py --config Configs/copy-claims-denylist.json --text docs/apps/particle-universe/store-listing.md --swift Packages/ExperiencesCreative/ParticleUniverse/Experience/ParticleControls.swift Packages/ExperiencesCreative/ParticleUniverse/Experience/ParticlePresenter.swift
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-j2
python3 scripts/release_check.py --only app-ui-ios27-j3
python3 scripts/release_check.py --only app-ui-ios27-j4
python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions
python3 scripts/test_scripts.py
```

Expected: fixtures load as specified; drawing failure → failed → retry → running; checks pass; Release checks pass.
