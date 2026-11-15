# Data model: A10-P06

| Item | Fields | Rules |
|---|---|---|
| Release checklist row | Item, Area, Status, Evidence | status ∈ {verified, pending-campaign-ii, owner-action}; evidence or owner steps non-empty |
| Store claim row | Claim, Proving test | every claim has a test file and test name |
| Sample high-score file | `high-scores-<form>.json`, copied as `high-scores.json` | valid (board 1, three entries), newer (board 2), damaged (not JSON), truncated |
