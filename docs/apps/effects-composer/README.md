# Effects Composer (`a25.effects-composer`)

A visual effects-chain editor for building, previewing and exporting reusable shader looks (archived manual
`apps/25-effects-composer.md` §1–§2). Version 0.1 covers:
- a linear chain editor with five built-in effects and bounded parameters;
- editable reorder, enable and disable, and an immediate preview;
- a before and after compare, and preset saves;
- local image import through the system picker with scoped access;
- still export with dimension and format validation;
- controlled render-target pooling and shader compile diagnostics.

Non-goals: a video editor, arbitrary feedback loops or user-written code, and importing from a cloud library without
the person's choice. The chain is linear and acyclic; a typed graph stays possible later without being promised.

Effects Composer is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/EffectsComposer`, and it never has a standalone target. The effects and the built-in
test image are generated in code; an imported image is the person's input, never bundled. It works offline and sends
nothing; an image is read only from the system picker the person opens, and an export is written only when the person
chooses it. Its rules are the A25 subsection of the constitution (2.21.0).

The pending core (A25-P01) is `Packages/ExperiencesCreative/EffectsComposer/Core`: the five effects with bounded
parameters (`EffectDefinition.swift`), the chain of at most eight effects with its exact undo and redo
(`EffectChain.swift`, `ChainEditing.swift`), the versioned chain file (`ChainDocument.swift`), the test image made in
code (`TestImage.swift`), and each effect's CPU reference and fragment program (`EffectReference.swift`,
`EffectPrograms.swift`), tested in `CoreTests` inside a running render host.

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
