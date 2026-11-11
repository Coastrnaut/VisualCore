# Data model: A01-P06

| Entity | Where | Fields / rules |
|---|---|---|
| Privacy manifest | `Apps/GenerativeArtStudio/Resources/PrivacyInfo.xcprivacy` | `NSPrivacyTracking` false; `NSPrivacyTrackingDomains` []; `NSPrivacyCollectedDataTypes` []; `NSPrivacyAccessedAPITypes`: one entry per detected category with `NSPrivacyAccessedAPITypeReasons` |
| Release config | `docs/apps/<slug>/release.json` | `schema` 1, `bundleID`, `version`, `build`, `allowedUsageDescriptions` (keys), `requiredDocs` (paths), `checklist` (path), `privacyManifest` (bool), `icon` (bool) |
| Release checklist item | `docs/apps/<slug>/release-checklist.md` table | Area, Item, Status ∈ {`verified`, `pending-campaign-ii`, `owner-action`}, Evidence or steps (never empty) |
| Store claim | `store-listing.md` table | Claim, Test (file::test) or "removed" |
| Library fixture | `Core/Tests/…/Fixtures/library-v1/<uuid>.json` | 4 DocumentStore envelopes, kind `dev.visualcore.gas.composition`, schemaVersion 1, one per family |
| Scan report | JSON from `check_privacy_manifest.py --json` | `detected`, `declared`, `undeclared`, `unused`, `violations` |
