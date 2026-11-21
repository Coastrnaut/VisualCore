# Contract: device-rows.json for Wave Knot Keeper (R02-G03-10)

```text
python3 scripts/check_device_rows.py --experience r02-g03.wave-knot-keeper [--root <repo>]
  exit 0 and "device-rows r02-g03.wave-knot-keeper: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g03.wave-knot-keeper: <reason>"
```

The definition is `docs/apps/wave-knot-keeper/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/WaveKnotKeeper/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g03` runs the command above.
