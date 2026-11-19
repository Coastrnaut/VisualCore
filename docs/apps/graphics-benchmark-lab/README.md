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

The pending core (A24-P01) is `Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core`: the three benchmark cases
with their caps and fingerprints (`BenchmarkCase.swift`), the frame sample and its validation (`FrameSample.swift`), the
nearest-rank statistics with quality flags (`Statistics.swift`) and the run file (`BenchmarkRun.swift`: kind
`a24.benchmark-run`, schema 1), tested in `CoreTests` against committed fixtures, and inside a running render host to
prove that none of it creates a graphics resource.

The runner (A24-P03) measures only measurement-phase frames and flags a frame dropped above 25 ms; a GPU time comes only
from VisualCore's `GPUFrameTimer` where the renderer offers `GL_EXT_disjoint_timer_query` (it does on the iOS 27.2
simulator; simulator values are not device evidence), and each finished run carries a report of its device, OS, build,
renderer, tier, thermal state and timing sources from public APIs only (run file version 2).

Results (A24-P04) are kept in the experience's own storage (at most 12, with the case's every setting stored in run
file version 3) and export as the JSON run file or a CSV through the share sheet only when the person taps Export.

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
