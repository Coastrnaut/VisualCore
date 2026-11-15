# Tiny Worlds (`a12.tiny-worlds`)

A curated gallery of miniature procedural environments explored with an orbit camera and gently customized (archived
manual `apps/12-tiny-worlds.md` §1–§2), for players who enjoy miniature dioramas, creators arranging small worlds and
people seeking low-pressure exploration. Version 0.1: three small world presets (island, asteroid garden and miniature
city); an orbit camera with constrained zoom and comfortable control; seeded terrain and mesh generation with stable
boundaries; prop placement and scene light adjustment; saved world compositions with thumbnails; a dynamic detail tier
within a GPU and memory budget. Non-goals: infinite terrain or open-world streaming, multiplayer world creation,
photorealistic global illumination and full physics gameplay.

Tiny Worlds is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in
`Packages/ExperiencesCreative/TinyWorlds`; it never has a standalone target. Terrain, props, skies and lighting are
drawn in code (procedural meshes and shaders, no models or textures as assets). A world document (preset, seed, props,
lighting) generates the same world every time and drawing never changes it. It reuses VisualCore's orbit camera, mesh
builders, generators, validation and budgets, the mesh renderer with its directional light and fog, the depth pass,
seeded random numbers, render-target read-back, storage and quality tiers; seeded noise and height-field terrain are
built in VisualCore (gaps of the contract), the rest in the experience. Its rules are the A12 subsection of the
constitution (2.8.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |

Phases: A12-P00 boundary audit (feature 088), P01 procedural seed and mesh fixtures, P02 camera and scene renderer,
P03 world customization and persistence, P04 three environment packs, P05 memory, thermal and content QA, P06 release
readiness; then the experience's integration gate X-A12.
