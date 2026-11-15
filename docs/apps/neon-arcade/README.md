# Neon Arcade (`a10.neon-arcade`)

A compact arcade game with glow, particles and disciplined game logic (archived manual `apps/10-neon-arcade.md`
§1–§2). Version 0.1 is one complete game, **Neon Dodge**: a player lane, falling hazards and collectible orbs, played
at a deterministic fixed step from a seed; authoritative collision between the player, hazards and orbs;
start/pause/restart/game-over flows with local scores; touch steering with configurable sensitivity; glow and particle
feedback constrained by readability; sound and haptic toggles with reduced-flash controls. Non-goals: a whole arcade
collection, online leaderboards, user-generated levels, loot boxes or purchasable currency.

Neon Arcade is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in
`Packages/ExperiencesCreative/NeonArcade`; it never has a standalone target. The player, hazards, orbs, glow and
backgrounds are drawn in code and any sound is synthesized in code (no artwork, no recordings). It reuses VisualCore's
seeded fixed-step clock and runner, particles, batched 2D shapes with hit testing, gestures, bloom, haptic and
announcement planning, storage and quality tiers; 2D collision with swept tests and synthesized sound-effect playback
are built in VisualCore (gaps of the contract), the rest in the experience. Its rules are the A10 subsection of the
constitution (2.6.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
| [content-licenses.md](content-licenses.md) | Author and license of the player, every hazard and every orb (generated) |

Phases: A10-P00 boundary audit (feature 074), P01 fixed-step engine and collision fixtures, P02 Neon Dodge mechanics,
P03 visual effects and audio/haptics, P04 scores and accessibility, P05 balance and device QA preparation, P06
release readiness; then the experience's integration gate X-A10.
