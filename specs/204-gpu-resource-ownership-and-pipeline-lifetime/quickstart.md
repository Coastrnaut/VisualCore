# Quickstart: R02-F04 evidence

```bash
swift test --package-path Packages/VisualCore
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/verify_experiences.py --only a01.generative-art-studio a02.fluid-art-playground a03.fractal-explorer --runtime 27
python3 scripts/check_public_api.py --update
python3 scripts/check_documented_api.py --sources Apps/VisualCore
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
python3 scripts/test_scripts.py
```

Expected: every command PASS. The whole VisualCoreRenderingTests target runs in the scheme runs (all five bundles),
including ProgramCacheTests (held evicted program draws correctly; live programs 0 at close), PipelineTests (state
read back after apply from 3 prior states; stale program refused and counted) and DepthTargetTests (nearer colour wins
in both orders; colour and depth storage released). A01–A03 digests unchanged; reference regression 7 of 7.

