# Data Model: A20-P04 (feature 148)

- **`library.json`:** envelope kind `a20.garden-library`, schema 1, `{next: Int, entries: [{file, name, order}]}`.
- **`garden-<n>.json`:** envelope kind `a20.saved-garden`, schema 1, `{name, order, document}`; ≤ 262,144 bytes.
- **`GardenLibrary`:** `entries` (name, file, readable or its refusal code), `save(name:document:)` (replace on an
  existing name), `open(_:) -> GardenDocument`, `rename(_:to:)`, `delete(_:)`; caps 12 gardens, names 1…40
  characters after trimming; messages "The library holds 12 gardens." and "A garden is already called <name>.".
- **`GardenStill`:** 1600 × 1200 PNG, one file in `TemporaryFolder("DigitalZenGarden-Still")`; `export() ->
  Result<URL, StillFailure>`.
- **Bounded history:** `done.count ≤ 100`; encoded done + undone ≤ 2,457,600 bytes; document within its caps.
- **As built (convergence T-A20-410):**
  - Opening builds an `ExperienceSnapshot` from the saved document with the shell's current seed and step and the
    document's digest, and restores it through the shell; the selection and tool reset.
  - The garden files are the truth and `library.json` is an index: the counter is max(index next, highest file
    number + 1); a damaged index is rebuilt by the next change; a newer-version index makes the library read only.
  - Unreadable files count toward the 12-garden cap and can be deleted by hand.
  - Names are compared without case, and a save keeps the new spelling. Each save takes order max + 1, a rename keeps
    it, and the list shows readable gardens newest first.
  - Unreadable codes are `damaged`, `newer-version`, `too-large` or the document's own refusal code.
  - Further refusals: a garden over 262,144 bytes is refused before writing; invalid name, not found, read only,
    unavailable, and a storage code. Announcements: "Saved/Opened/Deleted <name>." and "Renamed <old> to <new>."
  - Identifiers `library-name`, `library-save`, `library-replace-confirm`, `library-open-<n>`, `library-rename-<n>`,
    `library-rename-name`, `library-rename-confirm`, `library-delete-<n>`, `library-delete-confirm`,
    `library-unreadable-<n>`, `library-message`, `still-make`, `still-share`, `still-message`.
  - The still is "Zen Garden 1600x1200.png"; failures `no-renderer`, `render`, `encoding`, `write`.
  - Pickers and menus carry a title and a separate value ("Rake" and "Fine rake").
