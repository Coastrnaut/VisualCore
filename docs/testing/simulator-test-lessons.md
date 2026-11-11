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

## Feature 020 (A02-P02)

- **Validated configurations can change what a fixture runs.** A configuration clamp (a minimum grid edge of 16)
  silently turned "8×8" fixtures into 16×16 ones. Assert the size actually built (`scene.dye?.width`), not just the
  size requested, and print the real value in fixture logs.
- **iOS 26 content swipe-back.** A navigation stack pops on a horizontal swipe anywhere in the content. Canvas
  screens with drag gestures apply `VisualCoreUI.contentSwipeBackDisabled()`. UI tests should include a horizontal
  drag and then assert that the screen is still present. The iOS 26.5 runtime showed the bug; iOS 27.2 did not.
- **Exactly storable zero.** In 8-bit storage, a signed encoding centered at 0.5 is not storable, so a field at rest
  drifts. Use `SignedRangeEncoding.unorm8(range:)`.
- **Swift 6 UI tests.** `expectation(for:evaluatedWith:)` plus `waitForExpectations` does not compile under strict
  concurrency in a UI test class. Poll the element's label with a short run loop instead.
- **Other apps' DerivedData goes stale after VisualCore API changes.** Clear `Build/DerivedData/<App>` before
  rebuilding each consumer.

## Feature 021 (A02-P03)

- **Sheets on iOS 26 stay translucent.** `presentationBackground` alone was not enough. The form paints its own
  opaque background (`scrollContentBackground(.hidden)` plus a grouped background color), or the canvas shows
  through and fails contrast.
- **Glass bar buttons cast shadows the audit samples.** On iOS 26.5 the shadow of the Done button overlapped the
  first section header's frame and was flagged as low contrast. A top content margin fixed the layout; no exclusion
  was added.
- **Secondary system styles.** Section footers are forced to secondary text, and destructive buttons are system red;
  both nearly fail contrast on grouped backgrounds. Use prominent headers, regular rows for explanations and the
  accessible accent for non-destructive actions.
- **Sliders in UI tests.** On iOS 26, `adjust(toNormalizedSliderPosition: 0)` does not move a slider whose thumb is
  away from the start. Move to a position just inside the range and assert the direction of the change.
- **Inactive uniforms.** `FieldPass` rejects uniforms the compiler removed. Shared uniform sets are filtered per pass
  with `pass.program.uniforms`.
- **Measure before setting thresholds.** A 50% divergence-reduction target written before measuring was not reachable
  with the standard scheme. Set criteria from measured fixture data and record the numbers.

## Feature 022 (A02-P04)

- **Spoken labels must read observed state.** A canvas description computed from a non-observable object (the
  render scene) never refreshed in SwiftUI. Read the model's observed properties, and assert the label changes after
  a control changes.
- **Sheets with result text at XXXL.** Wrap the content in a scroll view, give each text
  `fixedSize(horizontal: false, vertical: true)`, and open the sheet at the large detent; otherwise the audit flags
  clipped text.
- **Offscreen captures for pixel probes.** `renderOffscreen` at exactly the grid size (scene paused) gives one pixel
  per cell, so display formulas can be checked pixel by pixel against a CPU reference (within 0.5/255 here).

## Feature 023 (A02-P05)

- **Stress tests find real defects; fix the cause.** The first 600-frame stress run in half-float storage reached
  |v| 34,688 cells/s and dye 89, because splats added force and dye without a bound. 8-bit storage passed only
  because its encoding clamps. The fix is to bound what splats add, in the shader and the CPU reference, rather than
  loosen the detector. Run every stress test in both storages.
- **Byte-identical determinism holds on the simulator.** With a fixed step, a pinned quality tier and a seeded
  gesture script, two runs give the same SHA-256. Here the digest was even identical across the iOS 27.2 and 26.5
  runtimes. Claim it per runtime and device only.
- **Several scripted fingers pinch.** Multi-pointer scripts must go through the painting path, not the gesture
  recognizer, or two simultaneous pointers become a pinch.
- **Lazy forms hide new rows.** Adding a picker pushed an existing row below the fold on the iOS 26.5 simulator's
  smaller window. Scroll until each queried element exists before reading its label.
- **One host per scene under automation.** `AutomationView` owns the RenderHost, so the app model must be able to run
  unhosted (`hosted: false`) with a stand-in canvas size.

## Feature 024 (A02-P06)

- **Bootstrap the privacy manifest from the scan.** Ship an empty manifest once, build Release, and read the
  scanner's undeclared categories. Then declare exactly those, with reasons from source checks. Never declare a
  category speculatively.
- **Look at a generated icon before committing it.** The stress settings of the test mode produced a washed-out
  white icon that still passed the provenance test. A gentle setting (default force, few slow strokes) gives a
  readable one. Provenance proves origin, not quality.
- **Simulator tests can read repository files through `#filePath`.** That lets a unit test check repository
  documents, such as store claims mapped to existing tests.
- **App containers keep Debug-only artifacts across runs.** A rehearsal report from an earlier automation launch was
  still in Documents. Privacy tests must list and explain such entries, not fail on them or hide them.
