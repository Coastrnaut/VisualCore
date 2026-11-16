# Interactive Anatomy (`a17.interactive-anatomy`)

A labelled, layer-controlled 3D reference of one anatomy region with plain-language descriptions (archived manual
`apps/17-interactive-anatomy.md` §1–§2), for students learning gross anatomy, educators presenting structures and
general learners. Version 0.1 covers:
- one region: the right knee joint;
- toggleable layered structure groups and an accessible structure list;
- selection highlighting, labels and searchable metadata;
- camera orbit and zoom with isolate and ghost controls;
- factual text with citations and provenance;
- download-free offline content.

Non-goals: diagnostic or treatment advice, a full-body atlas, and patient files.

Interactive Anatomy is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/InteractiveAnatomy`, and it never has a standalone target. Every structure is procedural
geometry made in code and labelled as a schematic model; no purchased, generated, scanned or hand-modelled meshes are
used. The text cites public-domain sources (Gray's Anatomy, 20th edition, 1918) and Terminologia Anatomica names. It
is labelled as not reviewed by a clinician until a person has reviewed it, and it is educational, not medical. Its
rules are the A17 subsection of the constitution (2.13.0).

| Document | Content |
|---|---|
| `visualcore-contract.json` / `.md` (written by T-A17-002 and T-A17-003) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
