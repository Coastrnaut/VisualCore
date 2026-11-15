# Contract: A09-P03 API (app-local; no VisualCore change)

## DigitalAquariumCore

```swift
public struct FoodPellet: Codable, Equatable, Sendable { public var position: Vec2 }
public enum Feeding {
    public static let maxPellets = 12, pelletsPerFeed = 3, spacing = 0.25, sinkSpeed = 0.5
    public static let seekRange = 4.0, seekWeight = 2.5, eatMargin = 0.15
    public static func canDrop(_ doc: HabitatDocument) -> Bool
    public static func drop(at point: Vec2, into doc: inout HabitatDocument) -> Bool   // false when refused
    public static func seekForce(for fish: FishAgent, food: [FoodPellet]) -> Vec2
    @discardableResult public static func step(_ doc: inout HabitatDocument, catalog: SpeciesCatalog, dt: Double) -> (eaten: Int, floored: Int)
}
public enum DecorEditing {
    public static func place(kindId: String, at point: Vec2, into doc: inout HabitatDocument) -> Bool
    public static func move(index: Int, to point: Vec2, in doc: inout HabitatDocument) -> Bool
    public static func remove(index: Int, from doc: inout HabitatDocument) -> Bool
    public static func tankPoint(fractionX: Double, fractionY: Double) -> Vec2
}
```

## Experience

Actions (refusal codes in parentheses): `food.drop [0…1, 0…1]` (`a09.food-full`), `decor.kind [0…2]`
(`a09.invalid-choice`), `decor.place [0…1, 0…1]` (`a09.decor-full`), `decor.move [0…11, 0…1, 0…1]`
(`a09.no-such-decor`, `a09.invalid-choice`), `decor.remove [0…11]` (`a09.no-such-decor`, `a09.invalid-choice`).
`AquariumGestures` (value type, internal): `init()`, `mutating func handle(_ event: PointerEvent, document:
HabitatDocument, catalog: SpeciesCatalog, viewSize: Vec2) -> [(control: String, values: [Double])]` (the catalog gives
the decor sizes for the hit test), `reset()`; it also tracks a second finger itself (the one-pointer declarations never
see it) and then sends nothing until every finger lifts. Drag outcomes carry `[x, y, dx, dy]`; the hit test uses the
touch-down point `(x − dx, y − dy)`. Presenter `gestureActions =
{food.drop, decor.place, decor.move}`, `nativeActions` ⊇ all five. Snapshot schema 3; `schemaTwoExample()`.
