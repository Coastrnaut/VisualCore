# Contract: Neon Arcade release configuration (`docs/apps/neon-arcade/release.json`, schema 1)

```json
{
  "schema": 1,
  "experience": "a10.neon-arcade",
  "requiredDocs": ["docs/apps/neon-arcade/privacy-and-credits.md", "docs/apps/neon-arcade/store-listing.md",
                   "docs/apps/neon-arcade/release-checklist.md", "docs/apps/neon-arcade/device-campaign.md",
                   "docs/release/build-and-archive.md"],
  "checklist": "docs/apps/neon-arcade/release-checklist.md",
  "copyCheck": {"text": ["docs/apps/neon-arcade/store-listing.md"],
                "swift": ["Packages/ExperiencesCreative/NeonArcade/Experience/ArcadeControls.swift",
                          "Packages/ExperiencesCreative/NeonArcade/Experience/ArcadePresenter.swift"],
                "allow": []}
}
```

`release_check.py` then provides the steps `experience-release-a10` and `copy-claims-a10`.
