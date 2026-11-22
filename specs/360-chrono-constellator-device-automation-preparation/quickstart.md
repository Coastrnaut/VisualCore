# Quickstart: R02-G06-10

```bash
python3 scripts/check_device_rows.py --experience r02-g06.chrono-constellator
```

```bash
python3 scripts/release_check.py --only device-rows device-rows-r02-g06
```

```bash
python3 scripts/test_scripts.py
```

Expected: the check prints `device-rows r02-g06.chrono-constellator: PASS (8 rows, 12 scenarios)`; every command exits 0.
