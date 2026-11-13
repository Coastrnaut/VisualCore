# Quickstart: R02-F03 evidence

```bash
swift test --package-path Packages/VisualCore
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test
python3 scripts/verify_experiences.py --only a01.generative-art-studio a02.fluid-art-playground a03.fractal-explorer --runtime 27
python3 scripts/check_doc_names.py docs/architecture/determinism.md
python3 scripts/check_public_api.py --update
python3 scripts/check_documented_api.py --sources Apps/VisualCore
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
python3 scripts/test_scripts.py
```

Expected: all PASS; existing `SeededRandomTests` unchanged and passing; A01–A03 scenario digests unchanged; the
parity test matches 64 of 64 values on both runtimes; the reference regression 7 of 7 in two chunks.
