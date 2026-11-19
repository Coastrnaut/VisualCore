# Data Model: Effects Composer — Phase 06

## Release documents
- `release.json`: `{schema: 1, experience: "a25.effects-composer", requiredDocs: [privacy-and-credits.md,
  store-listing.md, release-checklist.md, device-campaign.md, licenses.md, visualcore-contract.md,
  docs/release/build-and-archive.md], checklist, copyCheck: {text: [store-listing.md], swift: [the nine Experience
  Swift files], allow: ["share"]}}`.
- Checklist rows: `| Item | Status | Evidence |`, status ∈ {`verified`, `pending-campaign-ii`, `owner-action`}.

## Sample files (ExperienceTests/Fixtures)
| File | Content | Expected |
|---|---|---|
| snapshot-v1.json | core snapshot schema 1, a two-effect chain | restores |
| snapshot-newer.json | schema 2 | refused as newer |
| snapshot-damaged.json | cut JSON | refused as damaged |
| preset-current.json | `a25.preset` v1 | opens |
| preset-newer.json | version 2 | listed unreadable `newer-version` |
| preset-damaged.json | cut JSON | listed unreadable `damaged` |
| presets-current.json | `a25.preset-library` v1 | lists |
| presets-newer.json | version 2 | library read only |
| presets-damaged.json | cut JSON | looks listed from files |

## Seam
- `ComposerPresenter.failNextDraw: Bool` (internal, tests); `enum ComposerDrawError: Error { case injected }`, message
  "The picture could not be drawn.".
