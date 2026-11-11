# Simulator test lessons (implementation campaign)

Lessons observed on the reference host (Xcode 27.2, iOS 27.2 and 26.5 simulators) while building the apps. They
apply to every app phase. Simulator results remain non-device evidence (constitution V).

## A run can silently skip new test classes

**Observed:** A01-P04 (`t409-ui-all-ios26`) and A01-P05 (`t507-ui-all-ios26`). An iOS 26.5 run that followed an iOS
27.2 run in the same DerivedData executed only the test classes that existed at the previous 26.5 run. It reported
success and no skip. A rerun executed every class.

**Rule:** after every app suite run, check the log with

```bash
python3 scripts/check_test_enumeration.py --sources Apps/<App>/Tests/<Unit|UI> --log <xcodebuild log>
```

A run that fails this guard is not evidence. Rerun it, and record both runs in the task evidence.

## The app's DerivedData can keep a stale package framework

**Observed:** A01-P05 (T-A01-504, T-A01-511). After a public declaration was added to a local VisualCore package,
the app build compiled against the old framework in `Build/DerivedData/<App>` and failed with "cannot find …" or
"has no member …". Package-only builds succeeded.

**Rule:** after changing a VisualCore package's public API, delete the app's gitignored
`Build/DerivedData/<App>` before building the app.

## Prefer behavior over layout in UI assertions

`XCUIElement.adjust(toNormalizedSliderPosition:)` maps through the slider's current frame. A layout change, such as
a wider neighbouring button, moves the resulting value. Assert ranges and consistency between what the control
speaks and what the screen shows, not exact values. Sheets at a medium detent with background interaction pass
`app.swipeUp()` to the content behind them. Swipe on the sheet's own list, or expand it through its grabber.

## Feature 019 (A02-P01)

- **Regenerate after adding a file.** XcodeGen lists source files when it generates the project. A test file added
  afterwards is not compiled, and the scheme still passes: `t111-app-27` reported TEST SUCCEEDED without the new
  class. Run `xcodegen generate --spec project.yml` after adding any file. The enumeration guard catches the miss.
- **Unique package directory names.** SwiftPM and Xcode take a local package's identity from its directory name. A
  second `Apps/<App>/Core` collided with A01's (`Core: (null)`, "Missing package product"). Name domain packages
  `Apps/<App>/<App>Core`.
- **Half-float writes may truncate.** GLES leaves the float-to-half rounding of color writes implementation-defined.
  The iOS 27.2 and 26.5 simulators truncate, while uploads round to nearest. Compare GPU fields against
  `StoragePrecision.float16` and `.float16TowardZero` references and record which mode matched; never loosen the
  tolerance instead.
- **`run-check` never overwrites.** Rerun under a new attempt name (`-2`, `-3`). Failed attempts stay as evidence.
