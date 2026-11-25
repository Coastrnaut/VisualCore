# Contract: device-rows.json for Starlit Cartouche (R02-G16-10)

```text
python3 scripts/check_device_rows.py --experience r02-g16.starlit-cartouche [--root <repo>]
  exit 0 and "device-rows r02-g16.starlit-cartouche: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g16.starlit-cartouche: <reason>"
```

The definition is `docs/apps/starlit-cartouche/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/StarlitCartouche/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g16` runs the command above.
