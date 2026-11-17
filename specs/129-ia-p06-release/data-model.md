# Data model: A17-P06 (feature 129)

| Entity | Fields | Rules |
|---|---|---|
| Release checklist row | requirement, status (`verified` / `pending-campaign-ii` / `owner-action`), evidence | every row has a status and evidence |
| Store claim | claim, proving test (`File.swift testName` or interface class) | the test exists |
| View sample | file `view-{v2,v1,newer,damaged}.json` (AnatomyViewDocument envelope) | v2 opens; v1 opens migrated; newer and damaged leave the opening view; bytes unchanged |
