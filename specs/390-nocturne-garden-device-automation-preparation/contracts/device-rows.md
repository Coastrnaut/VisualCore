# Contract: device-rows.json for Nocturne Garden (R02-G09-10)

```text
python3 scripts/check_device_rows.py --experience r02-g09.nocturne-garden [--root <repo>]
  exit 0 and "device-rows r02-g09.nocturne-garden: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g09.nocturne-garden: <reason>"
```

The definition is `docs/apps/nocturne-garden/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/NocturneGarden/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g09` runs the command above.
