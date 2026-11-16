# Contract: Molecular Explorer scene, camera and state (feature 111)

```swift
public enum DisplayMode: Int, Codable, CaseIterable, Sendable {
    case ballAndStick = 0, spaceFilling = 1
    public var atomRadiusFactor: Double { get }          // 0.30 / 1.00
    public var showsBonds: Bool { get }
    public static let stickRadius = 0.12
}
public struct CameraSettings: Codable, Equatable, Sendable {
    public var turnSteps: Int; public var tiltSteps: Int; public var zoomSteps: Int
    public static let `default`: CameraSettings          // 2, 2, 0
    public mutating func turn(_ delta: Int)              // wraps 0…23
    public mutating func tilt(_ delta: Int) -> Bool      // false at ±8
    public mutating func zoom(_ delta: Int) -> Bool      // false at ±4
    public func camera(centre: Vec3, boundingRadius: Double, aspect: Double) -> OrbitCamera
}
public struct MoleculeScene: Equatable, Sendable {
    public struct AtomItem; public struct BondHalf
    public static let drawBudget = 1_500
    public let atoms: [AtomItem]; public let bondHalves: [BondHalf]
    public let centre: Vec3; public let boundingRadius: Double
    public init(molecule: Molecule, mode: DisplayMode)
}
// MoleculeState schema 2: selection, mode, camera; decode migrates schema 1.
```

Actions (adapter `MoleculeCore`): `display.mode [0/1]`, `camera.orbit [−1/+1]`, `camera.tilt [−1/+1]`,
`camera.zoom [−1/+1]`, `view.reset`; refusal `a15.camera-limit`.
