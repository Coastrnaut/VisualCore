# Contract: device-rows.json for Microscopic Aurora (R02-G19-10)

```text
python3 scripts/check_device_rows.py --experience r02-g19.microscopic-aurora [--root <repo>]
  exit 0 and "device-rows r02-g19.microscopic-aurora: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g19.microscopic-aurora: <reason>"
```

The definition is `docs/apps/microscopic-aurora/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/MicroscopicAurora/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g19` runs the command above.
