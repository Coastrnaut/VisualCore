# Data Model: A16-P00

- **Contract** (`docs/apps/simulation-lab/visualcore-contract.json`, schema 1 of `check_app_contract.py`, whose keys are
  fixed): top `schema`, `app`, `gate`, `date`, `inventory`, `matrix`, `gaps`, `traceability`, `negative`, `decision`;
  `inventory` [area, description, paths, owner]; `matrix` [id M##, capability, source, status ∈ {available, requires
  adaptation, upstream gap}, evidence [file, symbol, product, public], example {file, symbol}, notes]; `gaps` [id G-…,
  matrix (row ids), kind, owner (VisualCore module or app-local), justification, phase, test, closed]; `traceability`
  [item, matrix, phases]; `negative` [rule, source]; `decision` {result go|stop, reasons, blockers}.
- **Manual risks**: the checker has no risk key, so each of the manual's three risks is a `negative` entry whose rule
  names the owner, the verification method and the release-blocker condition, with `source` "manual §13 risk N".
- **Regression baseline** (Markdown): phase-start commit, reference pin, the 7 steps with command and result.
