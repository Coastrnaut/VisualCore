# Contract: device-rows.json for Voxel Origami (R02-G15-10)

```text
python3 scripts/check_device_rows.py --experience r02-g15.voxel-origami [--root <repo>]
  exit 0 and "device-rows r02-g15.voxel-origami: PASS (8 rows, 12 scenarios)"
  exit 1 and one line per problem: "device-rows r02-g15.voxel-origami: <reason>"
```

The definition is `docs/apps/voxel-origami/device-rows.json` in the schema of feature 310
(`specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md`); the manifest is
`Packages/ExperiencesRound02/VoxelOrigami/scenario-manifest.json`. `release_check.py` step
`device-rows-r02-g15` runs the command above.
