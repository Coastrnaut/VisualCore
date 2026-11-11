# Contract: palettes, pinch, capture and pass runs

## VisualCoreRendering

```swift
extension FieldPass {
    public struct Run: Sendable, Equatable { public let label: String; public let output: UInt32; public let outputIsFramebuffer: Bool
                                            public let inputs: [String: UInt32] }
    @MainActor public static var runObserver: ((Run) -> Void)?
}
```

The observer is called once per run, after validation and before the draw. For a target output, `output` is the
target's color texture name.

## App UI identifiers

- `fap.adjust.palette`: a segmented picker (Ink, Smoke, Glowing dye).
- `fap.adjust.brush`: a slider 0.005…0.25, with the value spoken as "N% of the canvas".
- `fap.capture`: a toolbar button that becomes a `ShareLink` (`fap.capture.share`) when the image is ready. Messages
  appear in `fap.capture.message`.
- The canvas label includes the palette name, for example "Glowing dye, …".
