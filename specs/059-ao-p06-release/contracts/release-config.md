# Contract: Audio Odyssey release configuration

`docs/apps/audio-odyssey/release.json` (schema 1, read by `scripts/check_experience_release.py` and
`scripts/release_check.py`):

```json
{"schema": 1, "experience": "a07.audio-odyssey",
 "requiredDocs": ["docs/apps/audio-odyssey/privacy-and-credits.md", "docs/apps/audio-odyssey/store-listing.md",
                  "docs/apps/audio-odyssey/release-checklist.md", "docs/apps/audio-odyssey/device-campaign.md",
                  "docs/release/build-and-archive.md"],
 "checklist": "docs/apps/audio-odyssey/release-checklist.md",
 "copyCheck": {"text": ["docs/apps/audio-odyssey/store-listing.md"],
               "swift": ["Packages/ExperiencesCreative/AudioOdyssey/Experience/OdysseyControls.swift",
                         "Packages/ExperiencesCreative/AudioOdyssey/Experience/OdysseyPresenter.swift"],
               "allow": ["audio", "music", "microphone"]}}
```
