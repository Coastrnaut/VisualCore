# Contract: device-rows.json for Acoustic Constellator (R02-G13-10)

```text
python3 scripts/check_device_rows.py --experience r02-g13.acoustic-constellator [--root <repo>]
  exit 0 and "device-rows r02-g13.acoustic-constellator: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g13.acoustic-constellator: <reason>"
```

The definition is `docs/apps/acoustic-constellator/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/AcousticConstellator/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g13` runs the command above.
