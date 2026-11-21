# Contract: device-rows.json for Lissajous Labyrinth (R02-G02-10)

```text
python3 scripts/check_device_rows.py --experience r02-g02.lissajous-labyrinth [--root <repo>]
  exit 0 and "device-rows r02-g02.lissajous-labyrinth: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g02.lissajous-labyrinth: <reason>"
```

The definition is `docs/apps/lissajous-labyrinth/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/LissajousLabyrinth/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g02` runs the command above.
