# Quickstart: validate the Phase 0 baseline

Prerequisites: project Mac with Xcode 27.2 (27B52), XcodeGen 2.46.0, CMake 4.4.5; `External/projectm-ios`
and its submodules initialized (ANGLE `gclient` tree present).

```bash
python3 scripts/verify_environment.py
python3 scripts/check_reference_clean.py
python3 scripts/inventory_reference.py
python3 scripts/inventory_reference.py --check-citations docs/architecture/current-rendering-pipeline.md
python3 scripts/run_reference_baseline.py --list
```

Each baseline step runs through the ledger helper, for example:

```bash
python3 Tools/python/desktop_runbook.py run-check --stage <current gate> --name ref-engine-xcframework \
  --timeout 3600 -- python3 scripts/run_reference_baseline.py --step engine-xcframework
```

Expected: every step exits 0; `check_reference_clean.py` still exits 0 afterwards; results tabulated
in `docs/verification/projectm-baseline.md`. No physical device is touched.
