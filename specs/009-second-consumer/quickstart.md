# Quickstart: Phase 8 validation

1. `swift test --package-path Harnesses/SecondConsumer/GardenKit` → garden rules pass.
2. `python3 scripts/check_documented_api.py --sources Harnesses/SecondConsumer` → 0 undocumented; `python3 scripts/test_scripts.py` → fixtures behave.
3. `xcodegen generate --spec Harnesses/SecondConsumer/SecondConsumer.yml`; `xcodebuild test … -scheme SecondConsumer -destination 'platform=iOS Simulator,id=<27.2/26.5>' CODE_SIGNING_ALLOWED=NO` → build (with post-build audit PASS) and smoke scenario pass.
4. Regression: R1–R5, compliance, docs.
Contract: [second-consumer.md](contracts/second-consumer.md).
