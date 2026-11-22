# Contract: device-rows.json for Chrono Constellator (R02-G06-10)

```text
python3 scripts/check_device_rows.py --experience r02-g06.chrono-constellator [--root <repo>]
  exit 0 and "device-rows r02-g06.chrono-constellator: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g06.chrono-constellator: <reason>"
```

The definition is `docs/apps/chrono-constellator/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/ChronoConstellator/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g06` runs the command above.
