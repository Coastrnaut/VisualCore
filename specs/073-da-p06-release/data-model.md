# Data model: A09-P06

| Item | Fields | Rules |
|---|---|---|
| Release checklist row | Item, Area, Status, Evidence | status ∈ {verified, pending-campaign-ii, owner-action}; evidence or owner steps non-empty |
| Store claim row | Claim, Proving test | every claim has a test file and test name |
| Sample saved file | `aquarium-<uuid>.json` | valid (format 1), newer (format 2), damaged (not JSON), mismatched id |
