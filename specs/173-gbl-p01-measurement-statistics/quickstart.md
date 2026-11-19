# Quickstart: A24-P01 (feature 173)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing GraphicsBenchmarkLabCoreTests
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app graphics-benchmark-lab --render
python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/GraphicsBenchmarkLab
sh -c '! grep -rnE "import (UIKit|SwiftUI|OpenGLES|Network)|URLSession|Date\(\)|ContinuousClock|CFAbsoluteTime" Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core'
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A24-P01 --timeout 595 --name <n> -- <command>`.
