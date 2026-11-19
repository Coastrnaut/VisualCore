# Quickstart: Effects Composer — Phase 06

1. `sh specs/185-ec-p06-release/scan-sources-release.sh` and `sh specs/185-ec-p06-release/scan-claims-release.sh` →
   PASS.
2. `python3 scripts/release_check.py --only experience-release-a25 copy-claims-a25` → exit 0.
3. Package tests on sim-27.2 (`EffectsComposerCoreTests EffectsComposerExperienceTests`) → ComposerRecoveryTests and
   ReleaseSampleTests pass, each under 10 s.
4. `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27
   app-unit-ios27 app-ui-ios27-g3` → exit 0.
5. `python3 scripts/verify_experiences.py --only a25.effects-composer --runtime 27` → exit 0.
