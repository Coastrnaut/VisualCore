# Contract: device-rows.json for Harmonic Bridges (R02-G12-10)

```text
python3 scripts/check_device_rows.py --experience r02-g12.harmonic-bridges [--root <repo>]
  exit 0 and "device-rows r02-g12.harmonic-bridges: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g12.harmonic-bridges: <reason>"
```

The definition is `docs/apps/harmonic-bridges/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/HarmonicBridges/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g12` runs the command above.
