# Living Wallpapers (`a19.living-wallpapers`)

A creator of procedural backgrounds exported as correctly sized still images, for people who design their own
backgrounds (archived manual `apps/19-living-wallpapers.md` §1–§2). Version 0.1 covers:
- curated procedural backgrounds with colour presets;
- iPhone and iPad canvas templates with crop and safe-area guides;
- still-image export in common formats with a verified colour profile;
- an optional short video export, only after encoder and resource feasibility is shown;
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
