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

The experience (A25-P02, a candidate until X-A25) compiles the chain into passes over two ping-pong targets and a
result (`Core/PassPlan.swift`) and draws a live preview of a 256 × 256 picture made in code with pooled targets
(`Experience/PreviewRenderer.swift`); every edit can be undone, a disabled effect changes nothing, and a broken effect
program is named with its line while the last good picture stays.

Editing, compare and presets (A25-P03): compare shows the untouched picture; up to 24 named looks are kept as versioned
files in the experience's own storage (`Experience/LookLibrary.swift`), unreadable files are listed and never deleted
automatically, and opening a look is one undoable edit; every effect can be moved, switched and tuned with named
accessibility actions, without dragging.

Image import (A25-P04): the `import` control opens the system photo picker, which runs outside the app and needs no
permission. `Experience/ImageImport.swift` decodes the picture off the main thread with ImageIO into upright sRGB RGBA
bytes, scaled so the longer edge is at most the smaller of the texture limit and 2,048 pixels; damaged, tiny (under
8 pixels) and oversized (over 50 MiB) data is refused with a message; a PNG cut short in its image data is
decoded by ImageIO with the missing rows blank rather than refused. The bytes go into the source target with
VisualCore's `RenderTarget.upload(rgba:)` and are uploaded again after a context rebuild. The picture is not stored:
a restored session shows the test picture, which `test-picture` brings back at any time.

Colour, export and robustness (A25-P05): grade, blur and vignette work on light values (decoded from sRGB on read and
encoded on write, `Core/ColorDomain.swift`), distort and posterize on stored values; intermediate pictures are
half-float where the device can draw into it and 8-bit otherwise, and an empty chain leaves the picture exactly as it
was. `export-png`, `export-jpeg` and `export-heic` draw the chain again at the picture's full size, refuse an
unavailable format or an oversized picture before drawing, write the file tagged sRGB in a temporary folder
(`Experience/StillExport.swift`) and offer it through the system share sheet (`share`); the file survives a context
rebuild and is removed before the next export and when the experience closes (the share sheet reports no completion,
so a shared file stays until then). A context loss rebuilds the same preview, an interrupted export
leaves no file, and a memory warning releases idle pictures. Device measurements are planned in
[device-campaign.md](device-campaign.md) and wait for ImplementationLock-100. Release work follows in A25-P06.

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
