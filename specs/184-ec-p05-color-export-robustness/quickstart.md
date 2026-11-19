# Quickstart: Effects Composer — Phase 05

1. Core: `python3 Tools/python/desktop_runbook.py run-check --stage A25-P05 --timeout 595 --name ec-ios27 --
   python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package
   --destination sim-27.2 --action test --only-testing EffectsComposerCoreTests EffectsComposerExperienceTests` →
   exit 0; ColorDomainTests, ColorPathTests, StillExportTests, RobustnessTests pass, each under 10 s.
2. Docs and isolation: `--name documented-api -- python3 scripts/check_documented_api.py --sources
   Packages/ExperiencesCreative/EffectsComposer`; `--name isolation -- python3 scripts/check_app_isolation.py
   --experiences Packages/ExperiencesCreative/EffectsComposer`; core purity as in A25-P04.
3. Contract: `--name contract -- python3 scripts/check_app_contract.py --app effects-composer --render` with G-COLOR,
   G-EXPORT and G-ROBUST closed by A25-P05.
4. App: `xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only
   app-build-for-testing-ios27 app-unit-ios27`; `--name verify-27 -- python3 scripts/verify_experiences.py --only
   a25.effects-composer --runtime 27`.
Expected: every check exit 0.
