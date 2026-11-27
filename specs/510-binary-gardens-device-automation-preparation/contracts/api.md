# Contract: device-rows.json for Binary Gardens (R02-G21-10)

```text
python3 scripts/check_device_rows.py --experience r02-g21.binary-gardens [--root <repo>]
  exit 0 and "device-rows r02-g21.binary-gardens: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g21.binary-gardens: <reason>"
```

The definition is `docs/apps/binary-gardens/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json`. `release_check.py` step `device-rows-r02-g21`
runs the command above. Self-test reasons: `scenario fixture-level-1-solved not in the manifest`, `scenario
no-such-scenario not in the manifest`, `BG-D1: missing field pass`, `T-R02G2109-011 not covered by any row`,
`T-R02G2104-011 not covered by any row`.
