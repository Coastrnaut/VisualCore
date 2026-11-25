# Contract: device-rows.json for Celestial Eclipse Lab (R02-G17-10)

```text
python3 scripts/check_device_rows.py --experience r02-g17.celestial-eclipse-lab [--root <repo>]
  exit 0 and "device-rows r02-g17.celestial-eclipse-lab: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g17.celestial-eclipse-lab: <reason>"
```

The definition is `docs/apps/celestial-eclipse-lab/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/CelestialEclipseLab/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g17` runs the command above.
