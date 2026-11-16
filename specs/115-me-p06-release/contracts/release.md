# Contract: release readiness (feature 115)

`docs/apps/molecular-explorer/release.json` (schema 1): experience `a15.molecular-explorer`; requiredDocs
privacy-and-credits.md, store-listing.md, release-checklist.md, device-campaign.md, data-review.md, data-sources.md,
docs/release/build-and-archive.md; checklist release-checklist.md; copyCheck text store-listing.md, swift
MoleculeControls.swift and MoleculePresenter.swift, allow `camera`. Interface chunk `w2` = `MEExploreUITests`,
`MELibraryUITests` (serial). `MoleculeCore.schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()` →
`MigrationExample?`. `MoleculePresenter.failNextDraw: Bool` (test seam; the next `draw` throws once).
