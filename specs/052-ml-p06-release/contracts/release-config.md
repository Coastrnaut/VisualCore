# Contract: Music Lab release configuration

`docs/apps/visualcore-music-lab/release.json` (schema 1, read by `scripts/check_experience_release.py` and
`scripts/release_check.py`):

```json
{"schema": 1, "experience": "a06.visualcore-music-lab",
 "requiredDocs": ["docs/apps/visualcore-music-lab/privacy-and-credits.md", "docs/apps/visualcore-music-lab/store-listing.md",
                  "docs/apps/visualcore-music-lab/release-checklist.md", "docs/apps/visualcore-music-lab/device-campaign.md",
                  "docs/release/build-and-archive.md"],
 "checklist": "docs/apps/visualcore-music-lab/release-checklist.md",
 "copyCheck": {"text": ["docs/apps/visualcore-music-lab/store-listing.md"],
               "swift": ["Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/MusicLabControls.swift",
                         "Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/MusicLabPresenter.swift"],
               "allow": ["audio", "music", "microphone"]}}
```
