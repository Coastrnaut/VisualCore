# Data model: R02-G08-10

| Entity | Fields | Rules |
|---|---|---|
| Definition | schema 1, experience, devices, scenarios, rows | sorted keys; schema 1 only |
| Device | name (D1, D2, D3), ledger (DEV1-R02-G08 …) | equal to the ledger's DEV rows of the experience, in order |
| Scenario | name | in the manifest; unique; 12 names |
| Row | id FF-D1 … FF-D8, title, devices, procedure, measurements, pass, gating, covers, owner_steps, status | every field present and non-empty; status "pending device campaign"; no result field; gating false only for FF-D6 |
| Covered item | task id (T-R02G0803-012, T-R02G0804-011, T-R02G0806-011, T-R02G0807-011, T-R02G0808-012, T-R02G0809-011), UA-F13 name (launch, first-frame, frame-pacing, memory, thermal, stress) | each covered by at least one row |
