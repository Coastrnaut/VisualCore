# Contract: device-rows.json for Faceted Forge (R02-G08-10)

```text
python3 scripts/check_device_rows.py --experience r02-g08.faceted-forge [--root <repo>]
  exit 0 and "device-rows r02-g08.faceted-forge: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g08.faceted-forge: <reason>"
```

The definition is `docs/apps/faceted-forge/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/FacetedForge/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g08` runs the command above.
