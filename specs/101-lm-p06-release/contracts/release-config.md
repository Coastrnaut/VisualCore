# Contract: Light Maze release configuration (feature 101)

`docs/apps/light-maze/release.json` (schema 1, read by `scripts/check_experience_release.py`):

```json
{
  "schema": 1,
  "experience": "a13.light-maze",
  "requiredDocs": [
    "docs/apps/light-maze/privacy-and-credits.md",
    "docs/apps/light-maze/store-listing.md",
    "docs/apps/light-maze/release-checklist.md",
    "docs/apps/light-maze/device-campaign.md",
    "docs/release/build-and-archive.md"
  ],
  "checklist": "docs/apps/light-maze/release-checklist.md",
  "copyCheck": {
    "text": ["docs/apps/light-maze/store-listing.md"],
    "swift": ["Packages/ExperiencesCreative/LightMaze/Experience/MazeControls.swift",
              "Packages/ExperiencesCreative/LightMaze/Experience/MazePresenter.swift"],
    "allow": []
  }
}
```
