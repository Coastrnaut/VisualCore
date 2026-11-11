# Data Model: Fractal Explorer — Phase 06

## Release manifest (`docs/apps/fractal-explorer/release.json`)

schema 1; scheme FractalExplorer; bundleID dev.visualcore.FractalExplorer; version 1.0.0; build 1;
allowedUsageDescriptions [NSPhotoLibraryAddUsageDescription]; requiredDocs (4); checklist; privacyManifest, icon,
licenses true.

## Bookmark fixture v1

A DocumentStore envelope (kind `dev.visualcore.fe.bookmark`, schemaVersion 1) holding one NamedLibrary entry with a
Bookmark payload (Julia mode, non-default seed, cap, palette, precision mode).
