# Quickstart: R02-G21-10

```bash
python3 scripts/check_device_rows.py --experience r02-g21.binary-gardens
```

```bash
python3 scripts/release_check.py --only device-rows-r02-g20 device-rows-r02-g21
```

```bash
python3 scripts/test_scripts.py
```

Expected: the check prints `device-rows r02-g21.binary-gardens: PASS (8 rows, 12 scenarios)`; every command exits 0.
No command contacts a device.
