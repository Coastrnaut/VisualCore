# Data Model: A24-P06 (feature 178)

- **release.json:** `{schema: 1, experience: "a24.graphics-benchmark-lab", requiredDocs: [...], checklist, copyCheck:
  {text, swift, allow: ["share"]}}`, after `docs/apps/visual-programming-lab/release.json`.
- **Release checklist rows:** an id, the item, the status (`verified` | `pending-campaign-ii` | `owner-action`) and
  the evidence.
- **Samples (`ExperienceTests/Fixtures/`):**

  | File | Kind | Expected |
  |---|---|---|
  | `snapshot-v1.json` | current snapshot (`BenchCore` schema 1) | opens |
  | `snapshot-newer.json` | newer snapshot | refused |
  | `snapshot-damaged.json` | damaged snapshot | refused |
  | `result-current.json` | saved result `a24.saved-result` v1 (run file v3) | opens |
  | `result-newer.json` | saved result | listed as unreadable, `newer-version` |
  | `result-damaged.json` | saved result | listed as unreadable, `damaged` |
  | `results-current.json` | index `a24.result-library` v1 | lists |
  | `results-newer.json` | index | the library is read-only |
  | `results-damaged.json` | index | results still listed from their files; the index is not rewritten by reading |

  Every file is byte-identical after reading. An oversized saved result (2,162,689 bytes, written by the test into
  its temporary storage, not committed) is listed as unreadable, `too-large`, and kept.
- **Recovery seam:** `BenchPresenter.failNextDraw`, internal. The next draw throws `BenchDrawError.injected` once.
