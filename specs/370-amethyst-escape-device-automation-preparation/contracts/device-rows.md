# Contract: device-rows.json for Amethyst Escape (R02-G07-10)

```text
python3 scripts/check_device_rows.py --experience r02-g07.amethyst-escape [--root <repo>]
  exit 0 and "device-rows r02-g07.amethyst-escape: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g07.amethyst-escape: <reason>"
```

The definition is `docs/apps/amethyst-escape/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/AmethystEscape/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g07` runs the command above.
