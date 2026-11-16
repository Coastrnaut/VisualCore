# Molecular Explorer (`a15.molecular-explorer`)

An approachable 3D molecule viewer with clear atom and bond styling and constrained structured-data import (archived
manual `apps/15-molecular-explorer.md` §1–§2), for chemistry students, teachers explaining molecular shape and
hobbyists exploring small molecules and structures. Version 0.1: a curated small-molecule library with source
attributions; ball-and-stick and space-filling display modes; orbit, pan, zoom and atom picking; element labels, bond
types and a metadata panel; a small XYZ file import with strict bounds and parser errors; and locally kept recent
molecules and visual settings. Non-goals: complete medicinal chemistry or predictive molecular dynamics, trusting
arbitrary PDB or complex input without validation, and chemical safety or therapeutic claims.

Molecular Explorer is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in
`Packages/ExperiencesCreative/MolecularExplorer`; it never has a standalone target. Atoms, bonds, highlights and
backgrounds are drawn in code (procedural geometry and shaders). Parsing, bond inference and picking are pure,
GPU-free rules; inferred bonds are marked as estimates, never as measured structure. Every bundled element property
and molecule records its source, units and license. Its rules are the A15 subsection of the constitution (2.11.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
