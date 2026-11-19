# Data Model: A25-P00

- **Contract** (`docs/apps/effects-composer/visualcore-contract.json`, schema 1 of `check_app_contract.py`):
  - top-level keys: `schema`, `app`, `gate`, `date`, `inventory`, `matrix`, `gaps`, `traceability`, `negative`,
    `decision`;
  - `inventory`: area, description, paths, owner;
  - `matrix`: id M##, capability, source, status ∈ {available, requires adaptation, upstream gap}, evidence (file,
    symbol, product, public), example (file, symbol), notes;
  - `gaps`: id G-… or U-…, matrix (row ids), kind ∈ {adaptation, upstream}, owner (`VisualCore:<Module>` or
    `app-local`, the checker's two forms), justification (required for app-local), phase 1–6, test, closed (null).
    U-RGBAUPLOAD is `upstream`, owner `VisualCore:VisualCoreRendering`; the G- gaps are `adaptation`, owner `app-local`;
  - `traceability`: item, matrix, phases;
  - `negative`: rule, source;
  - `decision`: result go|stop, reasons, blockers.
- **Manual risks:** each of the manual's three risks is a `negative` entry. Its rule names the owner, the verification
  method and the release-blocker condition; its `source` is "manual §13 risk N".
- **Regression baseline** (Markdown): phase-start commit, reference pin, and the 7 steps with command and result.
