# Quickstart: R02-G03-05

1. `swift test --package-path Packages/ExperiencesRound02` — certified solutions unchanged by `solve(_:from:winning:)`;
   hints on 2,000 seeded states over all 100 levels shorten the remaining solution; tutorial scripts on levels 1 … 3 win;
   500 failures are explained exactly; scripted progress through 100 levels obeys unlock and star rules; every date
   2026 … 2036 maps to a level; schema 1 payloads migrate to 2; the scenario manifest matches.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
   ExperiencesRound02-Package --destination sim-27.2 --action test` — the panel's hint levels, failure text, picker and
   modes through the presenter.
3. App unit tests, regression and `python3 scripts/test_scripts.py` (alone).
