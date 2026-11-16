# Contract: release readiness (feature 122)

`docs/apps/simulation-lab/release.json` (schema 1):
- experience `a16.simulation-lab`;
- requiredDocs: privacy-and-credits.md, store-listing.md, release-checklist.md, device-campaign.md,
  validation-report.md, visualcore-contract.md and docs/release/build-and-archive.md;
- checklist: release-checklist.md;
- copyCheck: text store-listing.md; swift SimulationControls.swift, SimulationPresenter.swift and SimulationLegend.swift;
  allow `share`.

Interface chunk `x2` = `SLExploreUITests` and `SLLibraryUITests` (serial). `SimulationPresenter.failNextDraw: Bool` is a
test seam: the next `draw` throws once. There are no schema examples (both schemas are at version 1).
