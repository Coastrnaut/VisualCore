# Quickstart: R02-F16

1. `swift test --package-path Packages/VisualCore --filter "GraphFoundationTests|RouteSearchTests|TimeExpandedGraphTests|MinimumCutTests|SubgraphMatcherTests|CertificateCheckerTests"`
   — expect all pass: seeded routes equal reference optima; earliest arrivals equal a reference simulation; cut sizes
   equal edge-disjoint route counts; placement counts equal an exhaustive reference; every honest certificate accepted
   and every tampered one refused; stored certificates round-trip.
2. `swift test --package-path Packages/VisualCore` — every existing test unchanged and passing.
3. `python3 scripts/check_public_api.py` after `--update` — the new declarations only.
4. Regression: ExperiencesCreative (sim-27.2), VisualCoreRendering (sim-27.2, sim-26.5), the reference regression in two
   chunks and `python3 scripts/test_scripts.py`.
