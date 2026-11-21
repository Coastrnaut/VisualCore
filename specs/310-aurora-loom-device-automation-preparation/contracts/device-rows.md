# Contract: device-rows.json and check_device_rows.py (R02-G01-10)

```text
python3 scripts/check_device_rows.py --experience r02-g01.aurora-loom [--root <repo>]
  exit 0 and "device-rows r02-g01.aurora-loom: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g01.aurora-loom: <reason>"
```

The definition lives at `docs/apps/<app-folder>/device-rows.json` where the folder is found from the experience id
(`r02-g01.aurora-loom` → `aurora-loom`). The manifest is the experience's `scenario-manifest.json` under
`Packages/ExperiencesRound02/<Name>/`, located by its `experience` field.
