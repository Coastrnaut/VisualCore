# Quickstart: UA-F10 evidence

Fast checks:

```bash
python3 scripts/check_app_targets.py
python3 scripts/check_experience_packages.py
python3 scripts/check_dependencies.py
python3 scripts/measure_build.py --check
python3 scripts/test_scripts.py
```

Core tests at their final paths (the Core packages are iOS-only targets of `Packages/ExperiencesCreative`; `swift test
--package-path <Core>` is not available for them, so the equivalent per Core is):

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing GenerativeArtStudioCoreTests
```

(and `FluidArtPlaygroundCoreTests`, `FractalExplorerCoreTests`, `ParticleUniverseCoreTests`).

Experience verification:

```bash
python3 scripts/verify_experiences.py --only a01.generative-art-studio a02.fluid-art-playground a03.fractal-explorer --runtime 27 26
```

Unified-app release-check steps (each below ten minutes):

```bash
python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/measure_build.py --milestone UA-F10
```

Reference regression (no framework change is planned; run once as the gate's guard):

```bash
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
```

When VisualCore changes (not planned): `python3 scripts/check_public_api.py --update`, `python3
scripts/check_documented_api.py --sources Apps/VisualCore`, and the two reference chunks above.

CI: after the push, `gh run list --workflow ci --limit 3`; the `app-build` job of the newest commit passes. A planted
Release-only break on a scratch commit fails it, then the scratch commit is reverted.
