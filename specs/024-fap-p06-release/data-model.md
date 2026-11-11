# Data Model: Fluid Art Playground — Phase 06

## TemporaryFolder (VisualCorePersistence)

| Member | Rule |
|---|---|
| `init(name:base:)` | `name` is a single path component; empty, `.`, `..` or one containing `/` gives `"Temporary"`. `base` defaults to `FileManager.default.temporaryDirectory`. |
| `url` | `base/name` |
| `makeFileURL(prefix:extension:)` | Creates the folder if needed; returns `url/<prefix>-<UUID>.<ext>` (prefix and extension sanitized the same way); never overwrites. |
| `fileCount` | Regular files in the folder (0 when missing). |
| `removeAll() -> Int` | Removes the folder; returns how many files it held; ignores errors; never touches anything outside `url`. |

## Release config (`docs/apps/fluid-art-playground/release.json`, schema 1)

- `scheme`: FluidArtPlayground.
- `bundleID`: dev.visualcore.FluidArtPlayground.
- `version`: 1.0.0; `build`: 1.
- `allowedUsageDescriptions`: [NSPhotoLibraryAddUsageDescription].
- `requiredDocs`: 4 documents.
- `checklist`.
- `privacyManifest`, `icon` and `licenses`: all true.

## Checklist row

| Field | Values |
|---|---|
| Area | Privacy, Assets, Credits, Accessibility, Tests, Data, Store, Build, Device, Performance |
| Status | `verified`, `pending-campaign-ii` or `owner-action` |
| Evidence or steps | A ledger check name, or exact owner steps |

## Stored data

None. `FluidConfiguration` schema version 1 is documented as the starting point of any future migration.
