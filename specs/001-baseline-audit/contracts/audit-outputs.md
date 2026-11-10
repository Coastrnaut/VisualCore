# Contract: Phase 0 audit scripts and outputs

| Script | CLI | Exit | Output |
|---|---|---|---|
| `scripts/inventory_reference.py` | `[--output PATH]` | 0, or 1 if a required kind is empty | `docs/architecture/reference-inventory.json` |
| `scripts/inventory_reference.py` | `--check-citations DOC` | 0 if all citations resolve, else 1 and lists failures | stdout |
| `scripts/check_reference_clean.py` | none | 0 clean, 1 tracked changes (lists them) | stdout |
| `scripts/run_reference_baseline.py` | `--list` / `--step NAME` | exit status of the step | log via `run-check` |

Baseline step names (in order): `engine-xcframework`, `xcodegen-main`, `xcodegen-rendererlab`,
`build-projectm-ios-sim`, `build-capturelab-sim`, `build-rendererlab-sim`,
`build-projectm-ios-generic`, `test-anglerendering-ios27`, `test-anglerendering-ios26`.

Citation syntax in documents: ``ref:`<path>`#`<symbol>` `` (path relative to the reference root).
