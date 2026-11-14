# Contract: Oscilloscope Studio release configuration

`docs/apps/oscilloscope-studio/release.json` (schema 1, read by `scripts/check_experience_release.py` and
`scripts/release_check.py`):

```json
{"schema": 1, "experience": "a08.oscilloscope-studio",
 "requiredDocs": ["docs/apps/oscilloscope-studio/privacy-and-credits.md", "docs/apps/oscilloscope-studio/store-listing.md",
                  "docs/apps/oscilloscope-studio/release-checklist.md", "docs/apps/oscilloscope-studio/device-campaign.md",
                  "docs/release/build-and-archive.md"],
 "checklist": "docs/apps/oscilloscope-studio/release-checklist.md",
 "copyCheck": {"text": ["docs/apps/oscilloscope-studio/store-listing.md"],
               "swift": ["Packages/ExperiencesCreative/OscilloscopeStudio/Experience/ScopeControls.swift",
                         "Packages/ExperiencesCreative/OscilloscopeStudio/Experience/ScopePresenter.swift"],
               "allow": ["audio", "microphone"]}}
```
