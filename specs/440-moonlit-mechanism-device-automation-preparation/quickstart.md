# Quickstart: R02-G14-10

```bash
python3 scripts/check_device_rows.py --experience r02-g14.moonlit-mechanism
```

```bash
python3 scripts/release_check.py --only device-rows device-rows-r02-g14
```

```bash
python3 scripts/test_scripts.py
```

Expected: the check prints `device-rows r02-g14.moonlit-mechanism: PASS (8 rows, 12 scenarios)`; every command exits 0.
