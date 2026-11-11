# Contract: app VisualCore contract checker

```text
python3 scripts/check_app_contract.py --app <slug> [--root DIR] [--render]
  reads   docs/apps/<slug>/visualcore-contract.json (data-model schema 1)
  checks  every validation rule in data-model.md; prints "PROBLEM: <row id>: <citation>: <reason>" per failure
  --render rewrites the generated block between <!-- BEGIN GENERATED --> and <!-- END GENERATED --> in
          docs/apps/<slug>/visualcore-contract.md (inventory, matrix, gap register, traceability, negative rules, decision)
          and fails if the file lacks the markers
  exit    0 PASS ("PASS: <n> rows, <m> citations, <g> gaps, decision <go|stop>"), 1 problems, 2 usage/schema error
```

App shell (Phase 00):
- Target `GenerativeArtStudio`: bundle `dev.visualcore.GenerativeArtStudio`, display name "Generative Art Studio".
- Home screen title "Generative Art Studio", with accessibility identifier `gas.home.title` and a spoken label.
- UI test `LaunchSmokeUITests.testLaunchShowsTitle` asserts the title exists within 10 seconds of launch.
