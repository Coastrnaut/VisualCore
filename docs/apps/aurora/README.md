# Aurora (`a21.aurora`)

A full-screen ambient aurora experience with procedural skies, gentle stars and optional sound (archived manual
`apps/21-aurora.md` §1–§2). Version 0.1 covers:
- three procedural sky presets with aurora ribbons, stars and cloud layers;
- colour, motion and intensity controls with sensible bounds;
- scene transitions and saveable preferences;
- a low-power static view and a reduced-flash mode;
- an optional ambient sound loop with its own control, synthesised in code;
- a full-screen view that hides its controls and restores them with a tap.

Non-goals: a forecast of real aurora activity, weather integration, required background audio and a promise of an
always-on screen. The scenes are stylized art, not a scientific depiction.

Aurora is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/Aurora`, and it never has a standalone target. Ribbons, stars, clouds and glow are drawn
in code, and the optional sound is synthesised in code, with no recording. It works offline, sends nothing, uses no
location and needs no permission. Its rules are the A21 subsection of the constitution (2.17.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
| [licenses.md](licenses.md) | Licenses and provenance of everything the experience draws |
| [device-campaign.md](device-campaign.md) | Device-campaign plan AU-D1 to AU-D8 (pending until the campaign after ImplementationLock-100) |
