# Quickstart: A25-P01

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing EffectsComposerCoreTests
python3 scripts/check_experience_packages.py
python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/EffectsComposer
python3 scripts/check_app_contract.py --app effects-composer --render
```

Expected: every core test passes on sim-27.2, each under 10 s; the package check passes with a pending core; every
public name is documented; the contract passes with G-MODEL and G-EFFECTS closed.
