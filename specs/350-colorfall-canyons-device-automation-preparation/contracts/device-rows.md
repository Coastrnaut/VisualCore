# Contract: device-rows.json for Colorfall Canyons (R02-G05-10)

```text
python3 scripts/check_device_rows.py --experience r02-g05.colorfall-canyons [--root <repo>]
  exit 0 and "device-rows r02-g05.colorfall-canyons: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g05.colorfall-canyons: <reason>"
```

The definition is `docs/apps/colorfall-canyons/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/ColorfallCanyons/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g05` runs the command above.
