# Graphics Benchmark Lab (`a24.graphics-benchmark-lab`)

A transparent, repeatable suite of GPU graphics workloads and instrumentation with measured-device caveats (archived
manual `apps/24-graphics-benchmark-lab.md` §1–§2). Version 0.1 covers:
- repeatable baseline scenes: textured quads (fill rate), shader ALU stress and particles;
- warm-up, controlled measurement and cool-down phases, with a capped duration and an immediate stop;
- frame-time percentiles and CPU submit time, and a GPU time only where a supported timer is confirmed;
- a device, OS, build, quality-tier and thermal-context report with provenance;
- results kept on the device and exported as versioned JSON or CSV when the person chooses;
- an in-app explanation of benchmark limits and variability.

Non-goals: ranking devices from a single run, GPU timer claims without a supported timer, private hardware
identifiers and automatic uploads. No benchmark number is set or published before it is measured on a device.

Graphics Benchmark Lab is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/GraphicsBenchmarkLab`, and it never has a standalone target. Every workload scene and
texture is generated in code. It works offline, sends nothing and needs no permission. Its rules are the A24
subsection of the constitution (2.20.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
