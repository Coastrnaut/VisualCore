# Quickstart: A09-P03 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app digital-aquarium --render
python3 scripts/test_scripts.py
```

Expected: all pass; feeding meets SC-A09-302 for ≥ 18 of 20 seeds; gesture tests prove tap → feed, long press →
place, drag on a piece → move and no cross-over; schema-1 and schema-2 snapshots restore; the runner's nine standard
scenarios pass and the manifest's ten fixtures pass in `AquariumManifestTests`; the contract records G-FEEDPLACE
closed by A09-P03.
