# Data Model: A23-P06 (feature 171)

- **release.json:** `{schema: 1, experience: "a23.visual-programming-lab", requiredDocs: [...], checklist, copyCheck:
  {text, swift, allow: []}}`, after `docs/apps/shader-studio/release.json`.
- **Release checklist rows:** an id, the item, the status (`verified` | `pending-campaign-ii` | `owner-action`) and
  the evidence.
- **Samples (`ExperienceTests/Fixtures/`):**

  | File | Kind | Expected |
  |---|---|---|
  | `snapshot-v1.json` | current snapshot (`LabCore` schema 1) | opens |
  | `snapshot-newer.json` | newer snapshot | refused |
  | `snapshot-damaged.json` | damaged snapshot | refused |
  | `graph-sample.json` (A23-P04) | saved graph `a23.saved-graph` v1 | opens |
  | `graph-newer.json` | saved graph | listed as unreadable, `newer-version` |
  | `graph-damaged.json` | saved graph | listed as unreadable, `damaged` |
  | `library-current.json` | index `a23.graph-library` v1 | lists |
  | `library-newer.json` | index | the library is read-only |
  | `library-damaged.json` | index | graphs still listed from their files; the index is not rewritten by reading |

  Every file is byte-identical after reading.
- **Recovery seam:** `LabPresenter.failNextDraw`, internal. The next draw throws `LabDrawError.injected` once.
