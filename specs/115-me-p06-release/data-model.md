# Data model: A15-P06 (feature 115)

| Entity | Fields | Rules |
|---|---|---|
| Release checklist row | item, area, status, evidence or steps | status ∈ verified, pending-campaign-ii (names ME-D#), owner-action (names the steps) |
| Store claim | text, proving test | the test exists in the repository |
| Sample stored file | kind (recent, settings, import); form: recent and settings valid, newer, damaged, oversized; import valid, damaged, oversized (an XYZ file has no schema version) | valid loads; others refused with their reason and stay byte-identical |
| Schema example | stored payload of schema 1, 2 or 3 in an envelope, digest after migration to 4 | restores in schema 4 with that digest |
| Device campaign row | id ME-D1…ME-D6, devices, what a person checks, pass rule | runs after ImplementationLock-100 |
