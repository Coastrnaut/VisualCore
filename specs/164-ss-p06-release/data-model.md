# Data Model: A22-P06 (feature 164)

- **release.json:** `{schema: 1, experience: "a22.shader-studio", requiredDocs: [...], checklist, copyCheck: {text,
  swift, allow: []}}`, after `docs/apps/aurora/release.json`.
- **Release checklist rows:** an id, the item, the status (`verified` | `pending-campaign-ii` | `owner-action`) and
  the evidence.
- **Samples (`ExperienceTests/Fixtures/`):**

  | File | Kind | Expected |
  |---|---|---|
  | `snapshot-v1.json` | current snapshot | opens |
  | `snapshot-p02.json` | snapshot without the optional fields | opens with the defaults |
  | `snapshot-newer.json` | newer snapshot | refused |
  | `snapshot-damaged.json` | damaged snapshot | refused |
  | `project-current.json` | saved project | opens |
  | `project-newer.json` | saved project | listed as unreadable, `newer-version` |
  | `project-damaged.json` | saved project | listed as unreadable, `damaged` |
  | `library-current.json` | index | lists |
  | `library-newer.json` | index | the library is read-only |

  Every file is byte-identical after reading.
- **Recovery seam:** `StudioPresenter.failNextDraw`, internal. The next draw throws `StudioDrawError.injected` once.
