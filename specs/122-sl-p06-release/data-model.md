# Data model: A16-P06 (feature 122)

| Entity | Fields | Rules |
|---|---|---|
| `release.json` | schema 1, experience `a16.simulation-lab`, requiredDocs, checklist, copyCheck {text, swift, allow ["share"]} | read by `check_experience_release.py` |
| Release checklist row | Item, Area, Status, Evidence | Status ∈ {verified, pending-campaign-ii, owner-action} |
| License inventory row | Item, Kind (preset, palette, shader), Source, License | license ∈ {original, public-domain} |
| Sample fixture | preset-{valid,newer,damaged,invalid}.json, state-{valid,newer,damaged}.json | answered as specified; byte-identical afterwards |
| `failNextDraw` | Bool (test seam) | the next `draw` throws once and clears it |
