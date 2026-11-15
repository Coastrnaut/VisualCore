# Data model: A14-P06 (feature 108)

| Entity | Fields | Rules |
|---|---|---|
| Release checklist row | Item, Area, Status, Evidence | status one of `verified`, `pending-campaign-ii`, `owner-action` |
| Store claim | claim text, proving test | each test exists and passes |
| Sample saved view | `view-valid` (loads), `view-newer` (refused newer-version), `view-damaged` (refused damaged), `view-oversized` (refused oversized) | byte-identical after the load |
| Schema example | envelope of schema 1, 2 or 3, digest after migration to 4 | restores through the migration chain |
