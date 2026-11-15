# Data model: A12-P06

| Item | Fields | Rules |
|---|---|---|
| Release checklist row | Item, Area, Status, Evidence | status ∈ {verified, pending-campaign-ii, owner-action}; evidence or owner steps non-empty |
| Store claim row | Claim, Proving test | every claim has a test file and test name that exist |
| Sample world file | form ∈ {valid, newer, damaged, truncated} | valid opens; newer → `newer-version`; damaged and truncated → `damaged`; all byte-identical after reading |
