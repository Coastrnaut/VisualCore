# Quickstart: A09-P04 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app digital-aquarium --render
python3 scripts/test_scripts.py
```

Expected: all pass; bubbles end at the surface and stay within 48 over 3,600 steps; layers order and tint as specified;
caustics differ over a second and hold with Reduce Motion; the broken shader falls back; the description and
announcements follow the wording and interval; unknown content is refused or skipped; the runner's nine standard
scenarios pass and the manifest's eleven fixtures pass in `AquariumManifestTests`; the contract records G-WATERFX and
G-HABITATA11Y closed by A09-P04.
