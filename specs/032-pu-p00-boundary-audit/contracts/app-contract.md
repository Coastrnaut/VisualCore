# Contract: Particle Universe VisualCore contract

Same contract as [A01's](../../011-gas-p00-boundary-audit/contracts/app-contract.md):
`python3 scripts/check_app_contract.py --app particle-universe [--render]` exits 0 only when every cited file
exists, every cited symbol is declared (public when `public: true`), every product exists, every
non-`available` row is covered by a gap with an owner, phase and test, and a decision is recorded. The release
check's `app-contracts` step runs it for every app.

Shell UI identifiers: `fap.home.title` (titled home, accessibility label "Particle Universe"), `fap.home`.
