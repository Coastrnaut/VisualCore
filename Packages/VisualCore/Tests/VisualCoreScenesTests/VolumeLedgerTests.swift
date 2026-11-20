// VolumeLedgerTests — feature 212 (R02-F12) T-R02F12-004 (FR-R02F12-005; SC-R02F12-002). 1,000 seeded sequential cuts
// of the unit cube balance after every cut and repeat identically; a plane that misses records 0 removed; a cut after
// the solid is gone records 0 removed and 0 remaining; the entry limit (an internal limit of 3) refuses the 4th cut and
// leaves the ledger unchanged.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct VolumeLedgerTests {
    static func unitCube() throws -> ConvexSolid { try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1, 1, 1)) }

    /// `count` seeded cuts. Nine planes in ten pass through a seeded interior point of the current solid (between its
    /// vertex centroid and a seeded vertex), every tenth through a seeded point of the cube, turned so the centroid is
    /// kept (these mostly miss once the solid is small). After about 120 cuts the solid is ~1e-20 and a sliver cut
    /// removes it whole (research R7 c); the remaining cuts record 0. Expects balance after every cut.
    static func run(count: Int) throws -> VolumeLedger {
        var random = SDFTestRandom(seed: 2_012)
        let cube = try unitCube()
        var ledger = VolumeLedger(solid: cube)
        for i in 0..<count {
            var n = random.point(1)
            while n.length < 1e-3 { n = random.point(1) }
            n = n.normalized
            // Once a sliver cut has sent the whole (tiny) solid to the removed side, the cube is the stand-in.
            let vertices = ledger.current?.vertices ?? cube.vertices
            var centre = Vec3.zero
            for p in vertices { centre += p }
            centre = centre / Double(vertices.count)
            let corner = vertices[min(Int(random.next() * Double(vertices.count)), vertices.count - 1)]
            var q = centre + (corner - centre) * (0.9 * random.next())
            let cubePoint = Vec3(random.next(), random.next(), random.next())
            if i % 10 == 0 {
                q = cubePoint
                if n.dot(centre - q) > 0 { n = -n }
            }
            let plane = try ClipPlane(normal: n, offset: n.dot(q))
            let result = try ledger.cut(by: plane)
            #expect(ledger.entries.count == i + 1)
            #expect(ledger.isBalanced, "cut \(i): imbalance \(ledger.imbalance)")
            #expect(ledger.entries[i].removed == result.removedVolume)
        }
        return ledger
    }

    @Test func thousandSeededCutsBalanceAndRepeat() throws {
        let first = try Self.run(count: 1_000)
        let second = try Self.run(count: 1_000)
        #expect(first == second)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(first) == encoder.encode(second))
        #expect(first.original == 1)
        var cutting = 0
        for entry in first.entries where entry.removed > 0 { cutting += 1 }
        #expect(cutting >= 50, "only \(cutting) of 1,000 cuts removed volume")
        #expect(first.imbalance <= VolumeLedger.balanceTolerance)
    }

    @Test func aMissRecordsNothingRemoved() throws {
        var ledger = VolumeLedger(solid: try Self.unitCube())
        let result = try ledger.cut(by: ClipPlane(normal: Vec3(1, 0, 0), offset: 2))
        #expect(result.removed == nil)
        #expect(ledger.entries.count == 1)
        #expect(ledger.entries[0].removed == 0)
        #expect(ledger.entries[0].remaining == 1)
        #expect(ledger.current == (try Self.unitCube()))
        #expect(ledger.imbalance == 0)
    }

    @Test func aCutAfterTheSolidIsGoneRecordsZero() throws {
        var ledger = VolumeLedger(solid: try Self.unitCube())
        _ = try ledger.cut(by: ClipPlane(normal: Vec3(1, 0, 0), offset: -1))
        #expect(ledger.current == nil)
        #expect(ledger.entries[0].removed == 1)
        #expect(ledger.entries[0].remaining == 0)
        let after = try ledger.cut(by: ClipPlane(normal: Vec3(0, 1, 0), offset: 0.5))
        #expect(after.kept == nil && after.removed == nil && after.cap.isEmpty)
        #expect(ledger.entries.count == 2)
        #expect(ledger.entries[1].removed == 0)
        #expect(ledger.entries[1].remaining == 0)
        #expect(ledger.isBalanced)
    }

    @Test func theEntryLimitRefusesTheNextCutUnchanged() throws {
        var ledger = VolumeLedger(solid: try Self.unitCube(), maxEntries: 3)
        for k in 1...3 { _ = try ledger.cut(by: ClipPlane(normal: Vec3(1, 0, 0), offset: 1 - 0.2 * Double(k))) }
        #expect(ledger.entries.count == 3)
        let before = ledger
        #expect(throws: ConvexSolidError.tooComplex("ledger")) {
            _ = try ledger.cut(by: ClipPlane(normal: Vec3(0, 1, 0), offset: 0.5))
        }
        #expect(ledger == before)
        #expect(ledger.isBalanced)
        #expect(abs(ledger.entries[2].remaining - 0.4) <= 1e-12)
        // The test limit survives the stored form.
        let back = try JSONDecoder().decode(VolumeLedger.self, from: JSONEncoder().encode(ledger))
        #expect(back == ledger)
        #expect(VolumeLedger(solid: try Self.unitCube()).limit == VolumeLedger.maxEntries)
    }
}
