# Simulation Lab (`a16.simulation-lab`)

A gallery of inspectable simulations with parameter panels and explicit numerical and educational limitations
(archived manual `apps/16-simulation-lab.md` §1–§2), for STEM hobbyists, educators demonstrating patterns and dynamics
and visual artists discovering reaction-diffusion forms. Version 0.1: three simulation families (cellular automata,
reaction-diffusion and a 2D wave field); a clear parameter schema per experiment with seeded starting conditions;
pause, reset, single step, speed and a histogram or legend overlay; a deterministic tiny CPU reference for each
algorithm; a GPU ping-pong path with explicit boundary rules; and saved presets and still capture. Non-goals: a
numerically certified scientific solver, large high-precision computation and multi-user experiments.

Simulation Lab is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in
`Packages/ExperiencesCreative/SimulationLab`; it never has a standalone target. Fields, colour ramps and overlays are
drawn in code (shaders). Every algorithm has a pure, seeded CPU reference on a tiny grid that the GPU path is compared
with; simulations are labelled as educational approximations. Its rules are the A16 subsection of the constitution
(2.12.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
