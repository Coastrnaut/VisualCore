# Visual Programming Lab (`a23.visual-programming-lab`)

A constrained node-graph editor for composing parameterized visuals without writing shader code (archived manual
`apps/23-visual-programming-lab.md` §1–§2). Version 0.1 covers:
- a typed node graph for scalar, colour, texture and time values;
- an initial node library: Time, Constant, Noise, Gradient, Mix, Blur and Output;
- a touch graph canvas with wire routing, zoom and selection;
- cycle detection and clear invalid-connection feedback;
- a preview that compiles a bounded acyclic graph into GPU passes drawn in the host's context;
- versioned graph persistence with migration.

Non-goals: arbitrary scripting or code execution, unbounded loops or feedback nodes, and a desktop-class editor with
hundreds of nodes. Every graph is validated (types, cycles, caps on nodes, edges and textures) before any pass is
compiled or any texture is allocated.

Visual Programming Lab is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/VisualProgrammingLab`, and it never has a standalone target. Node operators and example
graphs are written in code. It works offline, sends nothing and needs no permission. Its rules are the A23 subsection
of the constitution (2.19.0).

The pending core (A23-P01) is `Packages/ExperiencesCreative/VisualProgrammingLab/Core`: the value types and node
library (`ValueType.swift`, `NodeLibrary.swift`), the graph model with its limits (`VisualGraph.swift`: at most 32 nodes
and 64 connections), the graph file (`GraphDocument.swift`: kind `a23.visual-graph`, schema 1) and the checker
(`GraphChecker.swift`: types, order, cycles with their path, output rules), tested in `CoreTests` without the GPU except
a host test that proves checking creates no graphics resource.

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
