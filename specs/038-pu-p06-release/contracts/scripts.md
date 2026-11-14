# Contract: release scripts (A04-P06)

- `python3 scripts/check_experience_release.py --config docs/apps/particle-universe/release.json [--root DIR]`:
  prints `PASS: experience release a04.particle-universe, N documents, M checklist rows` and exits 0, or one
  `PROBLEM: …` line per missing document, unknown status or empty evidence and `FAIL: …`, exit 1.
- `python3 scripts/check_copy_claims.py --config Configs/copy-claims-denylist.json --text FILE… [--swift FILE…]`:
  prints `PASS: copy claims, N files` exit 0, or `PROBLEM: <file>:<line>: '<match>' (<reason>)` lines and `FAIL`,
  exit 1. Lines containing `copy-claims: allow` are skipped (for quoted denylist examples in documents).
- `scripts/release_check.py` (T-A04-617, T-A04-624): for every `docs/apps/<slug>/release.json` with an `experience`,
  the step `experience-release-<code>` runs `check_experience_release.py --config <it>`; when the config has
  `copyCheck`, the step `copy-claims-<code>` runs `check_copy_claims.py` on its `text` and `swift` files. `<code>` is the
  part of the experience id before the first dot (`a04`). Configs with a `scheme` (standalone apps) keep their
  `app-release-<slug>` step.
