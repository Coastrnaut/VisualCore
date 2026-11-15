# Contract: Tiny Worlds release configuration (`docs/apps/tiny-worlds/release.json`, schema 1)

```json
{
  "schema": 1,
  "experience": "a12.tiny-worlds",
  "requiredDocs": ["docs/apps/tiny-worlds/privacy-and-credits.md", "docs/apps/tiny-worlds/store-listing.md",
                   "docs/apps/tiny-worlds/release-checklist.md", "docs/apps/tiny-worlds/device-campaign.md",
                   "docs/release/build-and-archive.md"],
  "checklist": "docs/apps/tiny-worlds/release-checklist.md",
  "copyCheck": {"text": ["docs/apps/tiny-worlds/store-listing.md"],
                "swift": ["Packages/ExperiencesCreative/TinyWorlds/Experience/WorldsControls.swift",
                          "Packages/ExperiencesCreative/TinyWorlds/Experience/WorldsPresenter.swift"],
                "allow": []}
}
```

`release_check.py` then provides the steps `experience-release-a12` and `copy-claims-a12`.
