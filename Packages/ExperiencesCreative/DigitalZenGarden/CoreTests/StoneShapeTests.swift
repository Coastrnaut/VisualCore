// StoneShapeTests — feature 147 (A20-P03) T-A20-302 (FR-A20-301, FR-A20-302; clarification Q1; data-model.md
// "StoneShape"). The procedural stone shape: the kind tables, the centre contained and points outside the bounds not,
// rotation and scale respected, the wobble bounded by 6 % and deterministic per id, the dome height and the outline on
// the boundary. Short runs only.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct StoneShapeTests {
    /// A stone of the kind `kind` at `position`.
    private static func stone(_ kind: String, at position: Vec2 = Vec2(0.5, 0.5), rotation: Double = 0,
                              scale: Double = 1, id: UInt32 = 1) -> Stone {
        Stone(id: id, kind: kind, position: position, rotation: rotation, scale: scale, depth: 0)
    }

    @Test func theKindTablesFollowThePalette() {
        #expect(StoneShape.exponents == [2.0, 2.6, 2.0, 3.0, 2.2])
        #expect(StoneShape.heights == [0.6, 0.35, 0.7, 1.0, 0.8])
        #expect(StoneShape.exponents.count == GardenPalette.stones.count)
        #expect(StoneShape.maxWobble == 0.06)
        #expect(StoneShape(stone: Self.stone("granite-unknown")) == nil)
        for (index, kind) in GardenPalette.stones.enumerated() {
            let shape = StoneShape(stone: Self.stone(kind.id, scale: 1.5))
            #expect(shape?.kindIndex == index)
            #expect(shape?.exponent == StoneShape.exponents[index])
            #expect(abs((shape?.radiusX ?? 0) - kind.radiusX * 1.5) < 1e-12)
            #expect(abs((shape?.radiusY ?? 0) - kind.radiusY * 1.5) < 1e-12)
        }
    }

    @Test func theCentreIsContainedAndPointsOutsideTheBoundsAreNot() throws {
        for kind in GardenPalette.stones {
            let shape = try #require(StoneShape(stone: Self.stone(kind.id, rotation: 0.7, id: 9)))
            #expect(shape.contains(shape.centre), "\(kind.id)")
            #expect(abs(shape.height(at: shape.centre) - shape.peak) < 1e-12)
            let box = shape.bounds
            let outside = [Vec2(box.minX - 1e-4, shape.centre.y), Vec2(box.maxX + 1e-4, shape.centre.y),
                           Vec2(shape.centre.x, box.minY - 1e-4), Vec2(shape.centre.x, box.maxY + 1e-4),
                           Vec2(box.maxX + 1e-4, box.maxY + 1e-4)]
            for point in outside {
                #expect(!shape.contains(point), "\(kind.id) \(point)")
                #expect(shape.height(at: point) == 0)
            }
            #expect(!shape.contains(Vec2(Double.nan, 0.5)))
            // Every outline point lies inside the bounds.
            for point in shape.outline() {
                #expect(point.x >= box.minX - 1e-12 && point.x <= box.maxX + 1e-12)
                #expect(point.y >= box.minY - 1e-12 && point.y <= box.maxY + 1e-12)
            }
        }
    }

    @Test func rotationAndScaleAreRespected() throws {
        // The flat slate is twice as wide as tall: along its own x axis a point at 0.8 rx is inside, at 0.8 rx along
        // its y axis it is outside.
        let slate = GardenPalette.stones[1]
        let flat = try #require(StoneShape(stone: Self.stone(slate.id)))
        let alongX = Vec2(0.5 + 0.8 * slate.radiusX, 0.5)
        let alongY = Vec2(0.5, 0.5 + 0.8 * slate.radiusX / GardenPalette.smallTray.yScale)
        #expect(flat.contains(alongX) && !flat.contains(alongY))
        // Turned a quarter, the long axis points down the tray.
        let turned = try #require(StoneShape(stone: Self.stone(slate.id, rotation: Double.pi / 2)))
        #expect(!turned.contains(alongX) && turned.contains(alongY))
        // Doubled, a point at 1.5 rx is inside; at scale 1 it is not.
        let far = Vec2(0.5 + 1.5 * slate.radiusX, 0.5)
        let doubled = try #require(StoneShape(stone: Self.stone(slate.id, scale: 2)))
        #expect(doubled.contains(far) && !flat.contains(far))
        // Moving the stone moves the shape.
        let moved = try #require(StoneShape(stone: Self.stone(slate.id, at: Vec2(0.2, 0.3))))
        #expect(moved.contains(Vec2(0.2, 0.3)) && !moved.contains(Vec2(0.5, 0.5)))
    }

    @Test func theWobbleIsBoundedAndDeterministic() throws {
        let kind = GardenPalette.stones[2].id
        let a = try #require(StoneShape(stone: Self.stone(kind, id: 7)))
        let again = try #require(StoneShape(stone: Self.stone(kind, id: 7)))
        let other = try #require(StoneShape(stone: Self.stone(kind, id: 8)))
        #expect(a == again, "the same id gives the same shape")
        var differs = false
        var index = 0
        while index < 360 {
            let angle = Double(index) / 360 * 2 * Double.pi - Double.pi
            let factor = a.wobble(at: angle)
            #expect(abs(factor - 1) <= StoneShape.maxWobble + 1e-12, "angle \(angle)")
            if abs(other.wobble(at: angle) - factor) > 1e-6 { differs = true }
            index += 1
        }
        #expect(differs, "another id gives another wobble")
    }

    @Test func theDomeFallsToZeroAtTheOutline() throws {
        let shape = try #require(StoneShape(stone: Self.stone(GardenPalette.stones[4].id, rotation: -1.1, id: 3)))
        for point in shape.outline(samples: 64) {
            #expect(abs(shape.radialDistance(point) - 1) < 1e-9, "outline point \(point)")
            #expect(shape.height(at: point) < 1e-3)
        }
        let halfway = Vec2((shape.centre.x + shape.outline()[0].x) / 2, (shape.centre.y + shape.outline()[0].y) / 2)
        let height = shape.height(at: halfway)
        #expect(height > 0 && height < shape.peak)
        #expect(shape.outline(samples: 1).count == 3)
    }
}
