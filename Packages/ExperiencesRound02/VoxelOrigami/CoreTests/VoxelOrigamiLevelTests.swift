// VoxelOrigamiLevelTests — feature 441 (R02-G15-01) T-R02G1501-002 (FR-R02G1501-001, 009, 011, 013; SC-R02G1501-001,
// 005; clarifications Q1, Q4, Q5). The level's ranges and rules, its stored form (round trip, damaged, edited and newer
// forms refused), names in words, the rotation group and the fixtures' known turns. Explicit types and plain loops keep
// the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

@Suite("VoxelOrigamiLevel")
struct VoxelOrigamiLevelTests {
    /// An L of four cubes: 0 at the origin, 1 at +x, 2 at +x +x, 3 above 2 (+y in 2's frame).
    static let cubes: [VoxelOrigamiCube] = [
        .root,
        VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 0, 0), startTurn: 0),
        VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(1, 0, 0), startTurn: 0),
        VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(0, 1, 0), startTurn: 0),
    ]

    /// A square target (a 2 × 2 slab) the L cannot be at rest.
    static let square: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(0, 1, 0),
                                               VoxelOrigamiVector(1, 0, 0), VoxelOrigamiVector(1, 1, 0)]

    static func level(cubes: [VoxelOrigamiCube] = cubes, target: [VoxelOrigamiVector] = square,
                      orientations: VoxelOrigamiOrientations = .any,
                      budget: Int = 5) throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        try VoxelOrigamiLevel(id: "test-l", seed: 1, difficulty: 1, cubes: cubes, target: target,
                              orientations: orientations, budget: budget)
    }

    @Test func theRotationGroupHasTwentyFourDistinctOrthogonalElements() {
        let all: [VoxelOrigamiRotation] = VoxelOrigamiRotation.all
        #expect(all.count == 24)
        #expect(Set(all).count == 24)
        for a in all {
            for b in all { #expect(all.contains(a * b)) }
        }
        #expect(VoxelOrigamiOrientations.upright.group.count == 4)
        #expect(VoxelOrigamiOrientations.fixed.group == [.identity])
        #expect(VoxelOrigamiOrientations.any.group.first == .identity)
        let q = VoxelOrigamiRotation.quarter(about: VoxelOrigamiVector(0, 0, 1), turns: 1)
        #expect(q.applied(to: VoxelOrigamiVector(1, 0, 0)) == VoxelOrigamiVector(0, 1, 0))
        let back = VoxelOrigamiRotation.quarter(about: VoxelOrigamiVector(0, 0, -1), turns: 1)
        #expect(back.applied(to: VoxelOrigamiVector(0, 1, 0)) == VoxelOrigamiVector(1, 0, 0))
    }

    @Test func theRestPoseFollowsTheTree() throws {
        let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(Self.cubes, turns: [0, 0, 0, 0])
        let expected: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(1, 0, 0),
                                              VoxelOrigamiVector(2, 0, 0), VoxelOrigamiVector(2, 1, 0)]
        #expect(pose.cells == expected)
        // Turning hinge 2 (axis +x through cube 2) swings cube 3 from +y to +z.
        let turned: VoxelOrigamiPose = VoxelOrigamiLattice.pose(Self.cubes, turns: [0, 0, 1, 0])
        #expect(turned.cells[3] == VoxelOrigamiVector(2, 0, 1))
        #expect(turned.cells[2] == VoxelOrigamiVector(2, 0, 0))
    }

    @Test func aValidLevelBuildsAndRoundTrips() throws {
        let level: VoxelOrigamiLevel = try Self.level()
        #expect(level.hingeCount == 3)
        let data: Data = level.encoded()
        let decoded: VoxelOrigamiLevel = try VoxelOrigamiLevel.decode(data)
        #expect(decoded == level)
        #expect(decoded.fingerprint == level.fingerprint)
        let again: VoxelOrigamiLevel = try JSONDecoder().decode(VoxelOrigamiLevel.self, from: data)
        #expect(again == level)
        #expect(level.fingerprint.count == 64)
    }

    @Test func outOfRangeValuesAreRefusedByName() {
        func refused(_ name: String, _ make: () throws(VoxelOrigamiError) -> VoxelOrigamiLevel) {
            do {
                _ = try make()
                Issue.record("expected a refusal naming \(name)")
            } catch {
                #expect(error == .level(name), "expected \(name), got \(error)")
            }
        }
        refused("id") { () throws(VoxelOrigamiError) in
            try VoxelOrigamiLevel(id: "Bad Id", seed: 1, difficulty: 1, cubes: Self.cubes, target: Self.square,
                                  orientations: .any, budget: 5)
        }
        refused("difficulty") { () throws(VoxelOrigamiError) in
            try VoxelOrigamiLevel(id: "x", seed: 1, difficulty: 6, cubes: Self.cubes, target: Self.square,
                                  orientations: .any, budget: 5)
        }
        refused("cubes") { () throws(VoxelOrigamiError) in try Self.level(cubes: Array(Self.cubes.prefix(3))) }
        var badRoot: [VoxelOrigamiCube] = Self.cubes
        badRoot[0] = VoxelOrigamiCube(parent: nil, direction: VoxelOrigamiVector(1, 0, 0))
        refused("root") { () throws(VoxelOrigamiError) in try Self.level(cubes: badRoot) }
        var badParent: [VoxelOrigamiCube] = Self.cubes
        badParent[2] = VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(1, 0, 0))
        refused("parent") { () throws(VoxelOrigamiError) in try Self.level(cubes: badParent) }
        var badDirection: [VoxelOrigamiCube] = Self.cubes
        badDirection[1] = VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 1, 0))
        refused("direction") { () throws(VoxelOrigamiError) in try Self.level(cubes: badDirection) }
        var badTurn: [VoxelOrigamiCube] = Self.cubes
        badTurn[3] = VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(0, 1, 0), startTurn: 4)
        refused("turn") { () throws(VoxelOrigamiError) in try Self.level(cubes: badTurn) }
        var overlapping: [VoxelOrigamiCube] = Self.cubes
        overlapping[3] = VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(-1, 0, 0))
        refused("rest") { () throws(VoxelOrigamiError) in try Self.level(cubes: overlapping) }
        refused("target") { () throws(VoxelOrigamiError) in try Self.level(target: Array(Self.square.prefix(3))) }
        refused("target") { () throws(VoxelOrigamiError) in try Self.level(target: Self.square.reversed()) }
        let restCells: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(Self.cubes, turns: [0, 0, 0, 0]).occupied
        refused("solved") { () throws(VoxelOrigamiError) in try Self.level(target: restCells) }
        refused("budget") { () throws(VoxelOrigamiError) in try Self.level(budget: 0) }
        refused("budget") { () throws(VoxelOrigamiError) in try Self.level(budget: 41) }
    }

    @Test func damagedEditedAndNewerFormsAreRefused() throws {
        let level: VoxelOrigamiLevel = try Self.level()
        let text: String = String(decoding: level.encoded(), as: UTF8.self)
        #expect(throws: VoxelOrigamiError.malformed("unreadable")) {
            try VoxelOrigamiLevel.decode(Data("{".utf8))
        }
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(throws: VoxelOrigamiError.newerSchema(2)) { try VoxelOrigamiLevel.decode(Data(newer.utf8)) }
        let edited: String = text.replacingOccurrences(of: "\"budget\":5", with: "\"budget\":6")
        #expect(throws: VoxelOrigamiError.malformed("fingerprint")) {
            try VoxelOrigamiLevel.decode(Data(edited.utf8))
        }
        let broken: String = text.replacingOccurrences(of: "\"budget\":5", with: "\"budget\":0")
        #expect(throws: VoxelOrigamiError.malformed("r02-g15.level")) {
            try VoxelOrigamiLevel.decode(Data(broken.utf8))
        }
    }

    @Test func namesAreInWords() throws {
        let level: VoxelOrigamiLevel = try Self.level()
        #expect(level.cubeName(3) == "cube 3")
        #expect(level.hingeName(2, turn: 3) == "hinge 2, turned 270 degrees")
        let report: VoxelOrigamiShapeReport = level.report(turns: level.startTurns)
        let words: String = level.progressDescription(report: report, actionsLeft: 1)
        #expect(words.contains("of 4 cubes in place"))
        #expect(words.hasSuffix("1 action left"))
    }

    @Test func idleHingesCannotTurn() throws {
        let level: VoxelOrigamiLevel = try Self.level()
        #expect(!level.canTurn(3, turns: level.startTurns), "a leaf hinge")
        #expect(level.canTurn(1, turns: level.startTurns), "hinge 1 swings cube 3")
        #expect(level.canTurn(2, turns: level.startTurns))
        #expect(!level.canTurn(0, turns: level.startTurns))
        #expect(!level.canTurn(4, turns: level.startTurns))
    }

    @Test func fiveHundredFixturesBuildAndTheirKnownTurnsWinOnTheLast() {
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: 500)
        #expect(fixtures.count == 500)
        for fixture in fixtures {
            var turns: [Int] = fixture.level.startTurns
            let group: [VoxelOrigamiRotation] = fixture.level.orientations.group
            #expect(!fixture.level.report(turns: turns).matched)
            #expect(fixture.actions.count <= fixture.level.budget)
            for (index, action) in fixture.actions.enumerated() {
                guard let next = VoxelOrigamiFixture.apply(action, cubes: fixture.level.cubes, turns: turns) else {
                    Issue.record("\(fixture.level.id): action \(index) refused")
                    break
                }
                turns = next
                let matched: Bool = VoxelOrigamiLattice.canonical(fixture.level.pose(turns: turns).cells,
                                                                  group: group) == fixture.level.targetCanonical
                #expect(matched == (index == fixture.actions.count - 1), "\(fixture.level.id) action \(index)")
            }
            #expect(fixture.level.report(turns: turns).covered == fixture.level.cubes.count)
        }
    }
}
