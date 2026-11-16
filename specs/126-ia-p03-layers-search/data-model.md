# Data model: A17-P03 (feature 126)

| Entity | Fields | Rules |
|---|---|---|
| `DepthMeshPass.Item` (VisualCore) | renderer, model, color, `center` (model space, default origin) | translucent items sorted by view depth of `model × center`, farthest first; ties keep submission order |
| `AnatomySearch.Result` | part index, rank 0…4, matched text | rank order exact name, name prefix, exact synonym, synonym prefix, description prefix (query ≥ 3 characters); then index; ≤ 14; each part once |
| `AnatomyPanel` | heading, standard name, layer words, description, citations ["Title, edition, section (license)"], review sentence | a part with no citation is refused (content validation) |
| `AnatomyIsolate` | target (`.part(index)` or `.layer(AnatomyLayer)`), mode (`.ghost` default, `.hide`) | solid = target set ∪ selection; ghosts = other parts on shown layers in the ghost mode |
| `AnatomyViewState` schema 2 | schema 1 fields + `isolate` (kind `part`/`layer`, id, mode `ghost`/`hide`) | 1 → 2 adds no isolate; unknown ids dropped with reasons |
| `AnatomyViewDocument` | `DocumentEnvelope` kind `a17.view`, schema 2, payload | file `view.json`; ≤ 65,536 bytes; damaged or newer refused |
