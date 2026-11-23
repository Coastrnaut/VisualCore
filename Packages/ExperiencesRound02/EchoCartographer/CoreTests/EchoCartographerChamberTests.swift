// EchoCartographerChamberTests — feature 401 (R02-G11-01) T-R02G1101-003 (FR-R02G1101-002, 003, 014; SC-R02G1101-003;
// clarifications Q1, Q2). The exact chamber physics against independent references written here: on 500 seeded chambers
// and emitters (open emitters, with every tenth a wall), every ray equals explicit coordinate stepping x + k·dx, y + k·dy
// with a direct wall-set lookup (open cells nearest first, struck wall or nil at the border, distance at least 1, delay
// 24 × distance); every path length equals repeated relaxation to a fixed point over open side neighbours (no queue),
// with walls and unreachable cells nil and a wall emitter giving all nil; and the echoes are the reachable beacons'
// path lengths sorted, with delays 24 × distance. Hand cases on the 7 × 5 chamber: a wall next to the emitter, a ray to
// the border, a beacon on the emitter, and a beacon behind a wall reached around it. Explicit types, plain loops, short
// runs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import EchoCartographerCore

struct EchoCartographerChamberTests {
    /// The test seed.
    static let seed: UInt64 = 2_401
    /// The number of seeded chambers and emitters.
    static let caseCount: Int = 500

    static func cell(_ x: Int, _ y: Int) -> EchoCartographerCell { EchoCartographerCell(x: x, y: y) }

    /// One seeded case: a chamber, an emitter and the beacons of its echo.
    struct Case {
        let chamber: EchoCartographerChamber
        let emitter: EchoCartographerCell
        let beacons: [EchoCartographerCell]
    }

    /// The 500 seeded cases: chambers from the fixtures' generator; the emitter a random open cell, or a random wall
    /// cell for every tenth case (when the chamber has one); 0 … 4 beacons on distinct random open cells (reachable or
    /// not, the emitter included).
    static func cases() -> [Case] {
        var random = SeededRandom(seed: seed)
        var result: [Case] = []
        var index: Int = 0
        while result.count < caseCount {
            guard let chamber = EchoCartographerFixtures.chamber(&random) else { continue }
            var open: [Int] = []
            var walls: [Int] = []
            for k in 0..<(chamber.width * chamber.height) {
                if chamber.walls.contains(k) { walls.append(k) } else { open.append(k) }
            }
            guard !open.isEmpty else { continue }
            let emitterIndex: Int
            if index % 10 == 9 && !walls.isEmpty {
                emitterIndex = walls[random.int(0...(walls.count - 1))]
            } else {
                emitterIndex = open[random.int(0...(open.count - 1))]
            }
            let wanted: Int = min(random.int(0...4), open.count)
            var pool: [Int] = open
            var beacons: [EchoCartographerCell] = []
            for _ in 0..<wanted {
                let pick: Int = pool.remove(at: random.int(0...(pool.count - 1)))
                beacons.append(cell(pick % chamber.width, pick / chamber.width))
            }
            let emitter: EchoCartographerCell = cell(emitterIndex % chamber.width, emitterIndex / chamber.width)
            result.append(Case(chamber: chamber, emitter: emitter, beacons: beacons))
            index += 1
        }
        return result
    }

    /// Reference ray: the k-th cell is (x + k·dx, y + k·dy) for k = 1, 2, …; it stops at the first cell outside the
    /// grid (no wall) or in the wall set (that wall), at distance k.
    static func referenceRay(_ chamber: EchoCartographerChamber, _ from: EchoCartographerCell, dx: Int, dy: Int)
        -> (open: [EchoCartographerCell], wall: EchoCartographerCell?, distance: Int) {
        var open: [EchoCartographerCell] = []
        var k: Int = 1
        while true {
            let x: Int = from.x + k * dx
            let y: Int = from.y + k * dy
            if x < 0 || y < 0 || x >= chamber.width || y >= chamber.height { return (open, nil, k) }
            if chamber.walls.contains(y * chamber.width + x) { return (open, cell(x, y), k) }
            open.append(cell(x, y))
            k += 1
        }
    }

    /// Reference path lengths: the emitter 0 (when it is an open cell inside the grid), then whole sweeps over every
    /// cell setting d = min(d, neighbour + 1) over its open side neighbours, until a sweep changes nothing.
    static func referencePathLengths(_ chamber: EchoCartographerChamber, _ from: EchoCartographerCell) -> [Int?] {
        let width: Int = chamber.width
        let height: Int = chamber.height
        var lengths: [Int?] = Array(repeating: nil, count: width * height)
        let inside: Bool = from.x >= 0 && from.y >= 0 && from.x < width && from.y < height
        guard inside, !chamber.walls.contains(from.y * width + from.x) else { return lengths }
        lengths[from.y * width + from.x] = 0
        let offsets: [(Int, Int)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        var changed: Bool = true
        while changed {
            changed = false
            for y in 0..<height {
                for x in 0..<width {
                    let here: Int = y * width + x
                    if chamber.walls.contains(here) { continue }
                    for (dx, dy) in offsets {
                        let nx: Int = x + dx
                        let ny: Int = y + dy
                        if nx < 0 || ny < 0 || nx >= width || ny >= height { continue }
                        let there: Int = ny * width + nx
                        if chamber.walls.contains(there) { continue }
                        guard let neighbour = lengths[there] else { continue }
                        let candidate: Int = neighbour + 1
                        if let current = lengths[here], current <= candidate { continue }
                        lengths[here] = candidate
                        changed = true
                    }
                }
            }
        }
        return lengths
    }

    /// Every ray of 500 seeded chambers and emitters equals explicit coordinate stepping, field by field, in the order
    /// north, east, south, west, with distance at least 1 and delay 24 × distance.
    @Test func raysEqualCoordinateStepping() {
        let directions: [EchoCartographerDirection] = [.north, .east, .south, .west]
        let steps: [(Int, Int)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        var checked: Int = 0
        for (number, item) in Self.cases().enumerated() {
            for d in 0..<4 {
                let ray: EchoCartographerRay = item.chamber.ray(from: item.emitter, directions[d])
                let expected = Self.referenceRay(item.chamber, item.emitter, dx: steps[d].0, dy: steps[d].1)
                let label: String = "case \(number) emitter \(item.emitter) \(directions[d])"
                #expect(ray.direction == directions[d], Comment(rawValue: label))
                #expect(ray.open == expected.open, Comment(rawValue: label))
                #expect(ray.wall == expected.wall, Comment(rawValue: label))
                #expect(ray.distance == expected.distance, Comment(rawValue: label))
                #expect(ray.distance >= 1, Comment(rawValue: label))
                #expect(ray.open.count == ray.distance - 1, Comment(rawValue: label))
                #expect(ray.delay == 24 * expected.distance, Comment(rawValue: label))
                checked += 1
            }
        }
        #expect(checked == 4 * Self.caseCount)
    }

    /// Every path length of 500 seeded chambers and emitters equals repeated relaxation to a fixed point; walls and
    /// unreachable cells have none, and a wall emitter gives none at all.
    @Test func pathLengthsEqualRelaxation() {
        var wallEmitters: Int = 0
        for (number, item) in Self.cases().enumerated() {
            let lengths: [Int?] = item.chamber.pathLengths(from: item.emitter)
            let expected: [Int?] = Self.referencePathLengths(item.chamber, item.emitter)
            let label: String = "case \(number) emitter \(item.emitter)"
            #expect(lengths.count == item.chamber.width * item.chamber.height, Comment(rawValue: label))
            guard lengths.count == expected.count else { continue }
            for k in 0..<expected.count {
                let cellLabel: String = "\(label) cell \(k)"
                #expect(lengths[k] == expected[k], Comment(rawValue: cellLabel))
                if item.chamber.walls.contains(k) { #expect(lengths[k] == nil, Comment(rawValue: cellLabel)) }
            }
            if item.chamber.walls.contains(item.chamber.index(item.emitter)) {
                wallEmitters += 1
                var any: Bool = false
                for value in lengths where value != nil { any = true }
                #expect(!any, Comment(rawValue: label))
            } else {
                #expect(lengths[item.chamber.index(item.emitter)] == 0, Comment(rawValue: label))
            }
        }
        #expect(wallEmitters > 0)
    }

    /// The echo of 500 seeded chambers, emitters and beacons is the four reference rays and the reachable beacons'
    /// reference path lengths sorted ascending, with delays 24 × distance.
    @Test func echoesAreSortedBeaconPathLengths() {
        let directions: [EchoCartographerDirection] = [.north, .east, .south, .west]
        var unreachable: Int = 0
        for (number, item) in Self.cases().enumerated() {
            let echo: EchoCartographerEcho = item.chamber.echo(from: item.emitter, beacons: item.beacons)
            let reference: [Int?] = Self.referencePathLengths(item.chamber, item.emitter)
            var expected: [Int] = []
            for beacon in item.beacons {
                if let length = reference[beacon.y * item.chamber.width + beacon.x] {
                    expected.append(length)
                } else {
                    unreachable += 1
                }
            }
            expected.sort()
            var delays: [Int] = []
            for length in expected { delays.append(24 * length) }
            let label: String = "case \(number) emitter \(item.emitter) beacons \(item.beacons)"
            #expect(echo.emitter == item.emitter, Comment(rawValue: label))
            #expect(echo.beaconDistances == expected, Comment(rawValue: label))
            #expect(echo.beaconDelays == delays, Comment(rawValue: label))
            #expect(echo.rays.count == 4, Comment(rawValue: label))
            guard echo.rays.count == 4 else { continue }
            for d in 0..<4 {
                #expect(echo.rays[d] == item.chamber.ray(from: item.emitter, directions[d]), Comment(rawValue: label))
            }
        }
        #expect(unreachable > 0)
    }

    /// A wall next to the emitter is struck at distance 1 with no open cells crossed, delay 24.
    @Test func wallNextToTheEmitter() {
        let chamber: EchoCartographerChamber = EchoCartographerFixtures.handLevel().chamber
        let east: EchoCartographerRay = chamber.ray(from: Self.cell(2, 0), .east)
        #expect(east.open.isEmpty)
        #expect(east.wall == Self.cell(3, 0))
        #expect(east.distance == 1)
        #expect(east.delay == 24)
        let fromSide: EchoCartographerRay = chamber.ray(from: Self.cell(0, 1), .east)
        #expect(fromSide.open.isEmpty)
        #expect(fromSide.wall == Self.cell(1, 1))
        #expect(fromSide.distance == 1)
    }

    /// A ray to the border strikes no wall: from (0, 0) north leaves at once (distance 1) and south crosses the four
    /// open cells of column 0 and leaves at distance 5.
    @Test func rayToTheBorder() {
        let chamber: EchoCartographerChamber = EchoCartographerFixtures.handLevel().chamber
        let north: EchoCartographerRay = chamber.ray(from: Self.cell(0, 0), .north)
        #expect(north.open.isEmpty)
        #expect(north.wall == nil)
        #expect(north.distance == 1)
        let south: EchoCartographerRay = chamber.ray(from: Self.cell(0, 0), .south)
        #expect(south.open == [Self.cell(0, 1), Self.cell(0, 2), Self.cell(0, 3), Self.cell(0, 4)])
        #expect(south.wall == nil)
        #expect(south.distance == 5)
        #expect(south.delay == 120)
    }

    /// A beacon on the emitter answers with path length 0 and delay 0.
    @Test func beaconOnTheEmitter() {
        let chamber: EchoCartographerChamber = EchoCartographerFixtures.handLevel().chamber
        let echo: EchoCartographerEcho = chamber.echo(from: Self.cell(2, 2), beacons: [Self.cell(2, 2)])
        #expect(echo.beaconDistances == [0])
        #expect(echo.beaconDelays == [0])
    }

    /// A beacon behind a wall is reached around it: from (2, 0) the beacon (4, 0) is 2 straight steps away past the
    /// wall (3, 0) but 6 by the path through (2, 2) and (4, 2); from the entry the hand beacons answer 4 and 10.
    @Test func beaconBehindAWallReachedAroundIt() {
        let chamber: EchoCartographerChamber = EchoCartographerFixtures.handLevel().chamber
        let echo: EchoCartographerEcho = chamber.echo(from: Self.cell(2, 0), beacons: [Self.cell(4, 0)])
        let straight: Int = 2
        #expect(echo.beaconDistances == [6])
        #expect(echo.beaconDistances[0] > straight)
        #expect(echo.beaconDelays == [144])
        let entry: EchoCartographerEcho = chamber.echo(from: Self.cell(0, 0), beacons: [Self.cell(6, 0), Self.cell(2, 2)])
        #expect(entry.beaconDistances == [4, 10])
        #expect(entry.beaconDelays == [96, 240])
    }
}
