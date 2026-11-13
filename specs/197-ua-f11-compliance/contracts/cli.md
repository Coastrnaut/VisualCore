# Command-line contracts: UA-F11

Exit codes for every tool: `0` PASS, `1` findings (FAIL), `2` usage or unreadable input (path named on stderr).
Every tool prints one final line `PASS: …` or `FAIL: …` and, with `--json PATH`, writes the report of
data-model §7 atomically.

| Command | Inputs | Fails when |
|---|---|---|
| `check_no_tracking.py --app APP [--denylist F] [--symbols-file F] [--libraries-file F] [--json F]` | built app (all Mach-O files, linked libraries, bundled files) | a deny-listed framework is linked, symbol referenced or library name present; an allowance is unused |
| `check_compliance.py` (modified) | source tree | existing rules, plus advertising/tracking imports or APIs in sources |
| `check_usage_descriptions.py [--plist F | --app APP] [--registrations F] [--vocabulary F] [--json F]` | Info.plist, registrations, vocabulary | extra key, missing key, unknown word, text different from the vocabulary's |
| `build_catalog.py` (modified) | registrations | `permissions` not a list of 0–8 distinct vocabulary words |
| `check_licenses.py [--app APP] [--json F]` (modified) | inventory, manifests, and with `--app` the bundled `Licenses/` | existing rules; with `--app`: missing, extra or differing license file or index |
| `check_privacy_manifest.py --app APP [--json F]` (modified) | built app | unchanged rules; report gains `meta` |
| `check_distinctiveness.py (--write | --check) [--catalog F] [--titles F] [--json F]` | catalog, title list, matrix files | any `shares-mechanic` row, stale or wrong-coverage matrix, duplicate name/slug, known title; the message names the pair and says "redesign <later code> inside its concept" |
| `metadata_inputs.py (--write | --check) [--privacy-report F --tracking-report F] [--json F]` | ledger, catalog, registrations, reports | `--check`: file differs from a fresh generation |
| `report_meta.py` (module) | `meta(app: Path | None, configuration: str | None) -> dict` | — |
