# Quickstart: A09-P02 evidence (legacy ledger; iOS 27 only)

```bash
swift test --package-path Packages/VisualCore --filter "SteeringForceTests|NeighbourSearchTests"
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_public_api.py
python3 scripts/check_app_contract.py --app digital-aquarium --render
python3 scripts/test_scripts.py
```

Expected: all pass; steering tests prove the caps, the neighbour limit, group rules and determinism; schooling meets
SC-A09-201/202 for ≥ 18 of 20 seeds and the bounds hold over 10,000 steps × 20 seeds; a schema-1 state migrates with
starter decor; the manifest's seven fixtures pass; the contract records G-STEERING and G-FISHSWIM closed by A09-P02.
