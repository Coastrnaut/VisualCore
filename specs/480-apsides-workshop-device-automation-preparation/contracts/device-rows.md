# Contract: device-rows.json for Apsides Workshop (R02-G18-10)

```text
python3 scripts/check_device_rows.py --experience r02-g18.apsides-workshop [--root <repo>]
  exit 0 and "device-rows r02-g18.apsides-workshop: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g18.apsides-workshop: <reason>"
```

The definition is `docs/apps/apsides-workshop/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/ApsidesWorkshop/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g18` runs the command above.
