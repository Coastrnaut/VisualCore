# Contract: device-rows.json for Moonlit Mechanism (R02-G14-10)

```text
python3 scripts/check_device_rows.py --experience r02-g14.moonlit-mechanism [--root <repo>]
  exit 0 and "device-rows r02-g14.moonlit-mechanism: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g14.moonlit-mechanism: <reason>"
```

The definition is `docs/apps/moonlit-mechanism/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/MoonlitMechanism/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g14` runs the command above.
