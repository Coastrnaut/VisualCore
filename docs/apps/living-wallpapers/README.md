# Living Wallpapers (`a19.living-wallpapers`)

A creator of procedural backgrounds exported as correctly sized still images, for people who design their own
backgrounds (archived manual `apps/19-living-wallpapers.md` §1–§2). Version 0.1 covers:
- curated procedural backgrounds with colour presets;
- iPhone and iPad canvas templates with crop and safe-area guides;
- still-image export in common formats with a verified colour profile;
- no short video export: it was decided out of version 0.1 ([video-decision.md](video-decision.md));
- export progress, cancellation, error recovery and a local history;
- clear instructions for applying an exported image by hand.

Non-goals: setting the system wallpaper automatically or through private APIs, calling an export a live wallpaper,
and unlimited output sizes.

Living Wallpapers is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/LivingWallpapers`, and it never has a standalone target. Every background is a shader,
field, particle or SDF drawing made in code. An exported file leaves the device only through the system share sheet,
where the person may save it to Photos (with the app's add-only usage string) or to Files, and the person applies it
as a wallpaper through the system's own controls. Its rules are the A19 subsection of the constitution (2.15.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
| [video-decision.md](video-decision.md) | The short-video decision of Phase 01: no-go for version 0.1 |
| [licenses.md](licenses.md) | License and provenance of the scenes, colour presets and template data |
| [device-campaign.md](device-campaign.md) | Phase 05 device-campaign rows LW-D1 to LW-D8 (size limit, largest template, file size and profile, heat, memory, Photos prompt, declined path, audits), pending until the campaign after ImplementationLock-100 |
| [privacy-and-credits.md](privacy-and-credits.md) | Phase 06 privacy and credits: the snapshot, `history.json` and the temporary export file, how to delete them, nothing sent, the add-only Photos string, the license inventory |
| [store-listing.md](store-listing.md) | Phase 06 store text input with the claim → proving-test table |
| [release-checklist.md](release-checklist.md) | Phase 06 release checklist (verified, pending-campaign-ii LW-D1 to LW-D8, owner-action) and artifact inventory |
| [release.json](release.json) | Release configuration read by `scripts/check_experience_release.py` and `scripts/release_check.py` (`experience-release-a19`, `copy-claims-a19`) |
