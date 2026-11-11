# Research: A01-P03

- **R1 Atomic write.** Decision: encode → write to `<dir>/.<name>.tmp-<uuid>` → `FileManager.replaceItemAt(target,
  withItemAt: tmp)` (or `moveItem` when the target does not exist), then remove any leftover temporary files on the
  next listing. Rationale: replacement in the same directory is atomic on APFS, so readers see the old or the new
  file. An injectable failure hook simulates interruption. Alternative: `Data.write(options: .atomic)`, which is also
  atomic but cannot be interrupted deterministically in tests.
- **R2 Envelope.** JSON `{"kind": String, "schemaVersion": Int, "savedAt": ISO 8601, "payload": {...}}`, with sorted
  keys. The store checks the kind and version, then decodes the payload with the caller's `Codable` type after
  migration. Migration operates on JSON objects (`[String: Any]` via JSONSerialization), so old shapes need no old
  types.
- **R3 Listing.** `load()` enumerates `*.json` files only and skips hidden temporary files. For each file:
  - size above the limit → `.tooLarge` (checked from the file attributes before reading);
  - not valid JSON or not an envelope → `.corrupt`;
  - wrong kind → `.wrongKind`;
  - version above current → `.newerVersion(n)`;
  - payload decoding fails after migration → `.corrupt`.

  Files are never modified on any problem path.
- **R4 Library ordering and names.** Order is favorite, then modified descending, then name ascending. Names are
  trimmed and capped at 60 characters, and empty becomes "Untitled". A duplicate gets a new UUID, "<name> copy",
  `favorite = false` and new times.
- **R5 Leak fixture.** 200 iterations of palette, seed or preset edits, each followed by `ArtSceneFactory.apply` and a
  frame. Live counts come from `host.resources.stats` before and after the edits, and then after destroy.
