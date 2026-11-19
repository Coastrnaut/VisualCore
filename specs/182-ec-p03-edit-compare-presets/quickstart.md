# Quickstart: A25-P03

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing EffectsComposerCoreTests EffectsComposerExperienceTests
python3 scripts/check_app_contract.py --app effects-composer --render
python3 scripts/verify_experiences.py --only a25.effects-composer --runtime 27
```
