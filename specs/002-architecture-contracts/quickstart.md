# Quickstart: validate the Phase 1 contracts

```bash
python3 scripts/check_dependencies.py            # R1–R5 on the current repository: expect PASS
python3 scripts/test_scripts.py                  # includes seeded-violation tests (SC-F102)
swift package describe --package-path Packages/VisualCore          # scaffold resolves (host)
swift package describe --package-path Packages/VisualCoreRendering # scaffold resolves
python3 scripts/validate_docs.py && python3 scripts/check_compliance.py
```

Expected: every command exits 0. The seeded-violation tests prove the checker rejects a ProjectM
import outside the harness, a product cycle and a shared-package import of an app module. See
`contracts/package-map.md` for the rules.
