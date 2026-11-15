# Quickstart: A11-P01 evidence (legacy ledger; iOS 27 only)

```bash
swift test --package-path Packages/VisualCore --filter "Contacts2DTests|ImpulseSolver2DTests"
python3 scripts/check_public_api.py
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing PhysicsPlaygroundCoreTests PhysicsPlaygroundExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a11.physics-playground --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app physics-playground --render
python3 scripts/test_scripts.py
```

Expected: all pass; nine standard scenarios in the runner and ten fixtures in the manifest tests; the license document
matches the catalog; the contract records G-RIGIDBODY, G-CONTENTLICENSES and the contact part of G-CONTACTS closed by
A11-P01; 11 registered experiences, A11 a candidate.
