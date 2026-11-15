# Quickstart: A09-P05 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app digital-aquarium --render
python3 scripts/test_scripts.py
```

Expected: all pass; saved configurations round-trip through actions and damaged files are counted; ambient halves the
particles and slows the fish to 0.6; dimming at 60 s and restore on touch; three levels with monotone budgets and an
unchanged digest; the long run keeps every bound and the resource count is steady over five reopenings; the runner's
nine standard scenarios pass with three quality levels; the manifest's thirteen fixtures pass; the device campaign is
planned; the contract records G-AMBIENT closed by A09-P05.
