# Quickstart: R02-G19-10

```bash
python3 scripts/check_device_rows.py --experience r02-g19.microscopic-aurora
```

```bash
python3 scripts/release_check.py --only device-rows device-rows-r02-g19
```

```bash
python3 scripts/test_scripts.py
```

Expected: the check prints `device-rows r02-g19.microscopic-aurora: PASS (8 rows, 12 scenarios)`; every command exits 0.
