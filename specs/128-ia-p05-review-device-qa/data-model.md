# Data model: A17-P05 (feature 128)

| Entity | Fields | Rules |
|---|---|---|
| `AnatomyReviewRecord` | envelope kind `a17.review-record`, schemaVersion 1; payload contentVersion, entries | contentVersion equals the pack's (higher → newer-version, lower → damaged) |
| `AnatomyReviewEntry` | part id, kind (`editorial`/`clinical`), reviewer, date (ISO yyyy-MM-dd), method, sources [citation id] | unknown part → missing-reference; empty reviewer, date or method → empty-text; bad date → damaged; duplicate part + kind → duplicate-id; sources resolve to citations (missing-reference) |
| `AnatomyReview` | modelStatement, lines(for part) | editorial line "Text checked against its sources by the lead engineer on <date>."; clinical "Not reviewed by a clinician." or "Reviewed by <reviewer> on <date>." |
