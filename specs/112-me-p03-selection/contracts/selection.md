# Contract: Molecular Explorer selection, labels and bond styles (feature 112)

```swift
public enum AtomPicker {
    public static func pick(origin: Vec3, direction: Vec3, scene: MoleculeScene) -> Int?   // nearest drawn sphere
}
public enum LabelLayout {
    public struct Label: Equatable, Sendable { public let index: Int; public let symbol: String; public let point: Vec2 }
    public static let boxWidth = 24.0, boxHeight = 18.0, offset = 6.0
    public static func labels(scene: MoleculeScene, camera: OrbitCamera, canvas: Vec2, selected: Int?) -> [Label]
}
public struct BondStyle: Equatable, Sendable {
    public let sticks: Int; public let radius: Double; public let offsets: [Double]
    public static func style(order: Int, origin: BondOrigin) -> BondStyle
}
// CameraSettings: panX, panY (−10…10), pan(dx:dy:) -> Bool, target(centre:boundingRadius:) applies the pan.
// MoleculeState schema 3: selectedAtom; selectAtom(_:), nextAtom(), previousAtom(), clearAtom(); decode migrates 1 and 2.
// MoleculeScene: bond halves carry their style's sticks (each with its offset and radius).
```

Actions (adapter `MoleculeCore`): `camera.pan [dx, dy]`, `atom.select [0…499]`, `atom.next`, `atom.previous`,
`atom.clear`; refusals `a15.camera-limit`, `a15.invalid-choice`.
