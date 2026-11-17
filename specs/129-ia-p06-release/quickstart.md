# Quickstart: A17-P06 (feature 129)

1. Scans: `sh specs/129-ia-p06-release/scan-sources-release.sh`; `sh specs/129-ia-p06-release/scan-claims-release.sh`.
2. Package tests on sim-27.2 (`--only-testing InteractiveAnatomyCoreTests InteractiveAnatomyExperienceTests`).
3. App: `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-y2`.
4. Release: `python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a17 copy-claims-a17`.
5. Runner, contract, packages, scripts.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A17-P06 --timeout 600 --name <n> -- <command>`.
