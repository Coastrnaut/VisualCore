# Contract: PlaneViewport (VisualCore) and FractalExplorerCore

```swift
// VisualCoreMath
public struct PlaneViewport: Sendable, Equatable {
    public static let minUnitsPerPoint: Double   // 1e-15
    public static let maxUnitsPerPoint: Double   // 1e3
    public init(center: Vec2, unitsPerPoint: Double, size: Vec2)
    public static func framing(width: Double, center: Vec2, size: Vec2) -> PlaneViewport
    public private(set) var center: Vec2, unitsPerPoint: Double, size: Vec2, wasClamped: Bool
    public func plane(fromScreen p: Vec2) -> Vec2
    public func screen(fromPlane p: Vec2) -> Vec2
    public func pinched(by scale: Double, anchor: Vec2) -> PlaneViewport
    public func panned(by delta: Vec2) -> PlaneViewport
    public func resized(to size: Vec2) -> PlaneViewport
}
```

**PlaneViewport tests** (at least 8):
- round trips;
- an anchored pinch over 1e−6…1e6;
- the clamps report `wasClamped`;
- pan follows the finger;
- resize keeps the center and square pixels;
- 100 random resizes;
- non-finite inputs fall back;
- framing fits the shorter side;
- the y flip.

```swift
// FractalExplorerCore
public enum FractalMath {
    public static func escape(z0: Vec2, c: Vec2, cap: Int, radius: Double) -> EscapeResult
    public static func mandelbrot(_ c: Vec2, cap: Int, radius: Double) -> EscapeResult
    public static func julia(_ z: Vec2, seed: Vec2, cap: Int, radius: Double) -> EscapeResult
}
public struct FractalState: Sendable, Equatable { … ; public var spokenDescription: String }
public enum FractalExplanations { public static func text(for: FractalMode) -> String }
public struct Preview { public static func render(_ state: FractalState, maxSide: Int = 160, requestID: Int) -> Preview }
```

## App UI

- Home link `fe.home.open` opens the explorer.
- Picker `fe.mode` with Mandelbrot and Julia.
- Explanation `fe.mode.explanation`.
- Canvas image `fe.canvas`, whose label is the spoken description.
- Julia seed values `fe.seed`, shown as text.
