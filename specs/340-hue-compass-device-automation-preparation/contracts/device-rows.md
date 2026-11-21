# Contract: device-rows.json for Hue Compass (R02-G04-10)

```text
python3 scripts/check_device_rows.py --experience r02-g04.hue-compass [--root <repo>]
  exit 0 and "device-rows r02-g04.hue-compass: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g04.hue-compass: <reason>"
```

The definition is `docs/apps/hue-compass/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/HueCompass/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g04` runs the command above.
