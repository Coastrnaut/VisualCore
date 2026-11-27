# Quickstart: R02-G22-03

Host: `swift test --package-path Packages/ExperiencesRound02 --filter MyceliumArchitect` — adapter controls and
refusals, digest purity under tier, time and shown-pulse changes on 200 seeded snapshots, geometry finiteness and bounds
for extreme levels, painter's order, the CPU reference, shader sources (uniform slots ≤ 16, no samplers, palette equal to
Swift), scenario manifest. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
--scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MyceliumArchitectExperienceTests`
— frames of levels 1, 21, 41, 61, 81 at each tier match the CPU reference; forced shader failure shows the fallback.
App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27` — the candidate opens and is not
available.

Evidence (gate R02-G22-03): `baseline-*`, `host` …, `sim-27`, `app-unit`, `round02-host-1`, `-2`, `-3c`, `-3e`, `-3f`,
`rendering-27`, `rendering-26`, `experiences`, `host-full`, `reference-1`, `reference-2`, `script-tests` (alone).
