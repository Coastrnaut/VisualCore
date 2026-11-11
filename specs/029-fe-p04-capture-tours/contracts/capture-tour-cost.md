# Contract: cost, flights, tours, still capture and the explorer UI

## VisualCoreDiagnostics.RenderCostEstimate (public)

`init(pixels:iterations:samples:)`, `relative(to:)`, `enum Level { light, moderate, heavy }`,
`static level(ratio:lightMax:moderateMax:)`, `static text(ratio:)`. Tests ≥ 5: ratio 1 at the reference; doubling
each factor doubles; monotonic; levels at the thresholds; text formats (1×, 2.5×, 63×, 1.2e3×); invalid inputs.

## VisualCoreMath.FramingFlight, TourTimeline (public)

Flight tests ≥ 5: ends exactly; log span monotonic over 100 samples; target in view at every sample; equal spans move
linearly; route via the containing framing when the target is outside. Timeline tests ≥ 4: phases and stop indices
over time; holds; Reduce Motion jumps; finished state keeps the last stop. Nested types: `TourTimeline.Stop`,
`TourTimeline.Phase` and `TourTimeline.State` (framing, stopIndex, phase).

## VisualCoreMath precision spacing fixture

`PrecisionSpacingTests`: 23 and 10 bits within [1, 2] × true spacing for 48 magnitudes.

## VisualCoreRendering.StillCapture (public, @MainActor)

`init(folder:)`, `static folder(named:)`, `state` (`StillCapture.State`: idle, done(URL), failed(String)), `lastImage`, `capture(host:size:prefix:)`, `removeFile()`,
`static message(for:)`. Tests (both runtimes) ≥ 4: a capture writes a PNG of the requested size into the folder; a
second capture replaces the file; an invalid size fails with the message and leaves no file; `removeFile` deletes.

## App identifiers

`fe.cap` (slider, value "N iterations"), `fe.cap.down`, `fe.cap.up`, `fe.cost`, `fe.capture`, `fe.capture.share`,
`fe.capture.message`, `fe.capture.error`, `fe.tours`, `fe.tour.<id>`, `fe.tour.caption`, `fe.tour.stop`.
