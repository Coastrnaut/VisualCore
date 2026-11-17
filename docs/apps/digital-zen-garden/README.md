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
shadows are drawn in code. It works offline, sends nothing and needs no permission. Its rules are the A20 subsection
of the constitution (2.16.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
