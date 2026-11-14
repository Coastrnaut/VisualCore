# Data model: A08-P06

- **release.json** (schema 1): experience `a08.oscilloscope-studio`; requiredDocs (privacy-and-credits, store-listing,
  release-checklist, device-campaign, docs/release/build-and-archive.md); checklist; copyCheck.text (store-listing),
  copyCheck.swift (ScopeControls, ScopePresenter), copyCheck.allow ["audio", "microphone"].
- **Release checklist row**: Item, Area (privacy/data/copy/interface/build/device/owner), Status (verified, pending,
  blocked-owner, device), Evidence (check file or task id).
- **Preset fixture**: file name `scope-<uuid>.json`, content form (format 1, format 2, damaged, built-in claim),
  expected outcome (loads/newer/unreadable), expected settings for the loading files.
