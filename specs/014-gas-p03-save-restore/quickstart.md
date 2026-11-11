# Quickstart: A01-P03 validation

1. `swift test --package-path Packages/VisualCore`: DocumentStore tests pass. They cover atomic writes with an
   injected failure, listing with corrupt, newer, wrong-kind and too-large files left byte-identical, and the
   migration chain from a v0 fixture.
2. `swift test --package-path Apps/GenerativeArtStudio/Core`: CompositionLibrary tests pass (≥ 30 round trips,
   ordering, duplicate independence, rename rules, delete, update in place).
3. GenerativeArtStudio scheme tests on iOS 27.2 and 26.5:
   - `LibraryRenderTests`: save → new store → reload → identical image for 4 families; 200 rapid edits leak nothing;
   - `LibraryUITests`: save with a name, library list, favorite first, duplicate, rename, delete with confirmation;
     the saved composition survives a relaunch.
4. The release-check fast steps, the documented API for the app, the contract check and the 7-step reference
   regression all pass.
