# Digital Zen Garden (`a20.digital-zen-garden`)

A calm, tactile sand-raking and stone-arrangement experience whose compositions persist (archived manual
`apps/20-digital-zen-garden.md` §1–§2). Version 0.1 covers:
- one tray with visual sand relief, two rake styles and a stone palette;
- continuous multi-sample touch strokes with a brush preview;
- stone placement, rotation, deletion and layer-aware selection;
- undo and redo of strokes and placements;
- saving and loading named gardens with a lightweight stroke history;
- a low-stimulation mode, with sound and animation off by default.

Non-goals: granular material physics, online galleries or multiplayer, generative AI content and engagement loops.

Digital Zen Garden is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/DigitalZenGarden`, and it never has a standalone target. Sand, grooves, stones and
shadows are drawn in code. It works offline and sends nothing. Its only permission is the add-only Photos prompt
(`photo-library-add`), asked by the system when a still is saved through the share sheet. The calm switches (sound,
sand drift and haptics, all off by default) are kept as the experience value `calm.v1`. Its rules are the A20 subsection
of the constitution (2.16.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
| [device-campaign.md](device-campaign.md) | Device campaign plan, rows ZG-D1 to ZG-D8, all pending until after `ImplementationLock-100` |
| [privacy-and-credits.md](privacy-and-credits.md) | Phase 06 stored data, the temporary picture, permissions, what is not done, the license inventory |
| [store-listing.md](store-listing.md) | Phase 06 store text input with the claim → proving-test table |
| [release-checklist.md](release-checklist.md) | Phase 06 release checklist (verified, pending device campaign, owner action) and artifact inventory |
| [release.json](release.json) | Release configuration read by `scripts/check_experience_release.py` and `scripts/release_check.py` |
