# Contract: device-rows.json for Echo Cartographer (R02-G11-10)

```text
python3 scripts/check_device_rows.py --experience r02-g11.echo-cartographer [--root <repo>]
  exit 0 and "device-rows r02-g11.echo-cartographer: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g11.echo-cartographer: <reason>"
```

The definition is `docs/apps/echo-cartographer/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/EchoCartographer/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g11` runs the command above.
