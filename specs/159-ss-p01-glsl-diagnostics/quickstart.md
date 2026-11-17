# Quickstart: A22-P01 (feature 159)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing ShaderStudioCoreTests
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app shader-studio --render
sh -c '! grep -rnE "import (UIKit|SwiftUI|OpenGLES|Network)|URLSession|Date\(\)|ContinuousClock|CFAbsoluteTime" Packages/ExperiencesCreative/ShaderStudio/Core'
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A22-P01 --timeout 595 --name <n> -- <command>`.
