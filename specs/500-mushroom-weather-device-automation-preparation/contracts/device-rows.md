# Contract: device-rows.json for Mushroom Weather (R02-G20-10)

```text
python3 scripts/check_device_rows.py --experience r02-g20.mushroom-weather [--root <repo>]
  exit 0 and "device-rows r02-g20.mushroom-weather: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g20.mushroom-weather: <reason>"
```

The definition is `docs/apps/mushroom-weather/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/MushroomWeather/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g20` runs the command above.
