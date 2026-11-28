# API contract: R02-G22-04 (additions)

```swift
public enum MyceliumArchitectTool: String, Sendable, CaseIterable { case nutrient, blocker }
public enum MyceliumArchitectPickTarget: Sendable, Hashable { case empty, gauge, sprout(MyceliumArchitectDirection), root,
    cell(MyceliumArchitectCell) }
public enum MyceliumArchitectPicker {
    public static let allowance: Double                  // 12 points
    public static func pick(_ point: SIMD2<Double>, viewSize: SIMD2<Double>, snapshot: MyceliumArchitectSceneSnapshot,
                            orbit: MyceliumArchitectViewOrbit) -> MyceliumArchitectPickTarget
    public static func cast(_ point: SIMD2<Double>, viewSize: SIMD2<Double>, orbit: MyceliumArchitectViewOrbit)
        -> SIMD2<Double>?                                // the finger on the board plane z = 0
    public static func direction(from: SIMD2<Double>, to: SIMD2<Double>) -> MyceliumArchitectDirection
    public static func pulse(atPlaneX x: Double, pulsesRun: Int) -> Int }
public struct MyceliumArchitectViewOrbit: Sendable, Equatable { public let yaw, pitch: Double
    public static let authored: MyceliumArchitectViewOrbit; public static let yawRange, pitchRange: ClosedRange<Double>
    public func clamped() -> MyceliumArchitectViewOrbit; public func camera(aspect: Double) -> MyceliumArchitectCamera }
public enum MyceliumArchitectGestureAction: Sendable, Equatable { case send(String, [Double]), showPulse(Int),
    inspect(MyceliumArchitectCell?), preview(MyceliumArchitectAction), clearPreview,
    orbit(MyceliumArchitectViewOrbit), resetView, explain(String) }
public struct MyceliumArchitectGestureController: Sendable {
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public static let yawPerViewWidth, pitchPerViewHeight: Double
    public static let finishedReason, notRunningReason, rootReason, sproutReason: String
    public init()
    public mutating func handle(_ event: PointerEvent, viewSize: SIMD2<Double>, snapshot: MyceliumArchitectSceneSnapshot,
                                tool: MyceliumArchitectTool, orbit: MyceliumArchitectViewOrbit) -> [MyceliumArchitectGestureAction] }
extension MyceliumArchitectExperienceCore {
    public func previewReport(_ action: MyceliumArchitectAction) -> Result<MyceliumArchitectReport, MyceliumArchitectError> }
```
