# Digital Aquarium (`a09.digital-aquarium`)

A calming, customizable underwater habitat with autonomous fish, plants, bubbles and soft lighting (archived manual
`apps/09-digital-aquarium.md` §1). Audiences: families looking for a safe ambient experience, casual collectors who
customize habitats, people wanting a passive beautiful display (§2). Version 0.1: one complete aquarium with two fish
species and plants; bounded school behaviours and swim animation; tap-to-feed and decoration placement; bubbles,
caustics, depth layers and environmental particles; persistent habitat configurations with safe restore; a
low-motion, low-power ambient mode with automatic dimming. Non-goals: a realistic ecosystem or animal-care simulator,
a purchasable creature economy, an online multi-user aquarium.

Digital Aquarium is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in
`Packages/ExperiencesCreative/DigitalAquarium`; it never has a standalone target. Fish, plants, decor, bubbles and
caustics are drawn in code (no artwork). It reuses VisualCore's seeded fixed-step simulation, particles, batched 2D
shapes, gestures, effect passes, storage and quality tiers; bounded steering with a neighbour search is built in
VisualCore (a gap of the contract), the rest in the experience. Its rules are the A09 subsection of the constitution
(2.5.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |

Phases: A09-P00 boundary audit (feature 067), P01 habitat model and content license audit, P02 fish movement and
visual prototype, P03 editing, feeding and save system, P04 lighting, particles and accessibility, P05 ambient device
testing and release content, P06 final verification, privacy, packaging and release.
