# Quickstart: R02-G17-10

```bash
python3 scripts/check_device_rows.py --experience r02-g17.celestial-eclipse-lab
```

```bash
python3 scripts/release_check.py --only device-rows device-rows-r02-g17
```

```bash
python3 scripts/test_scripts.py
```

Expected: the check prints `device-rows r02-g17.celestial-eclipse-lab: PASS (8 rows, 12 scenarios)`; every command exits 0.
