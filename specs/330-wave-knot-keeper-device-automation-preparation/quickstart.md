# Quickstart: R02-G03-10

```bash
python3 scripts/check_device_rows.py --experience r02-g03.wave-knot-keeper
```

```bash
python3 scripts/release_check.py --only device-rows device-rows-r02-g03
```

```bash
python3 scripts/test_scripts.py
```

Expected: the check prints `device-rows r02-g03.wave-knot-keeper: PASS (8 rows, 12 scenarios)`; every command exits 0.
