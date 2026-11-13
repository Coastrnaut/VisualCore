# Contract: release scripts (A04-P06)

- `python3 scripts/check_experience_release.py --config docs/apps/particle-universe/release.json [--root DIR]`:
  prints `PASS: experience release a04.particle-universe, N documents, M checklist rows` and exits 0, or one
  `PROBLEM: …` line per missing document, unknown status or empty evidence and `FAIL: …`, exit 1.
- `python3 scripts/check_copy_claims.py --config Configs/copy-claims-denylist.json --text FILE… [--swift FILE…]`:
  prints `PASS: copy claims, N files` exit 0, or `PROBLEM: <file>:<line>: '<match>' (<reason>)` lines and `FAIL`,
  exit 1. Lines containing `copy-claims: allow` are skipped (for quoted denylist examples in documents).
