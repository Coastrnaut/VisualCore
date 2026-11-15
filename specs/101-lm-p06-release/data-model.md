# Data model: A13-P06 (feature 101)

No persisted format changes.

- **Release checklist row**: `Item | Area | Status | Evidence`; status ∈ {`verified`, `pending-campaign-ii`,
  `owner-action`}; verified rows cite a check file or test; device rows name their `device-campaign.md` row; owner rows
  give the steps.
- **Store claim**: `Claim | Proving test` (test names that exist in the repository).
- **Sample progress file**: `progress-valid.json` (loads; level 1 solved, level 2 open), `progress-newer.json`
  (`newer-version`), `progress-damaged.json` (`damaged`), `progress-truncated.json` (`damaged`); refused files
  byte-identical after loading; refused ones give fresh progress.
