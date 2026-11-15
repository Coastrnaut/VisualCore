# Contract: Physics Playground release configuration (`docs/apps/physics-playground/release.json`, schema 1)

```json
{
  "schema": 1,
  "experience": "a11.physics-playground",
  "requiredDocs": ["docs/apps/physics-playground/privacy-and-credits.md", "docs/apps/physics-playground/store-listing.md",
                   "docs/apps/physics-playground/release-checklist.md", "docs/apps/physics-playground/device-campaign.md",
                   "docs/release/build-and-archive.md"],
  "checklist": "docs/apps/physics-playground/release-checklist.md",
  "copyCheck": {"text": ["docs/apps/physics-playground/store-listing.md"],
                "swift": ["Packages/ExperiencesCreative/NeonArcade/Experience/ArcadeControls.swift",
                          "Packages/ExperiencesCreative/NeonArcade/Experience/ArcadePresenter.swift"],
                "allow": []}
}
```

`release_check.py` then provides the steps `experience-release-a11` and `copy-claims-a11`.
