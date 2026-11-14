# Data Model: A05-P00

- **Contract** (`docs/apps/infinite-geometry/visualcore-contract.json`, schema 1 of `check_app_contract.py`): `app`,
  `gate`, `inventory` [area, paths, notes], `matrix` [id M##, capability, status ∈ {available, requires adaptation,
  upstream gap}, evidence {files, symbols, products}, notes], `gaps` [id G-…, row, module, phase, description],
  `traceability` [source → rows], `negative` [rules], `decision` {verdict go|stop, reasons}.
- **Regression baseline** (Markdown): phase-start commit, reference pin, the 7 steps with command and result.
