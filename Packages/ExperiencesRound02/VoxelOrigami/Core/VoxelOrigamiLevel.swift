// VoxelOrigamiLevel — feature 441 (R02-G15-01) T-R02G1501-002 (FR-R02G1501-001, 004, 009, 011, 013, 014;
// SC-R02G1501-001, 003, 005; clarifications Q1, Q2, Q4, Q5). An immutable Voxel Origami level: 4 … 12 cubes (cube 0 the
// root with no parent, every other cube attached to a lower-index parent along one of the six rest directions in the
// parent's frame, with a starting quarter turn 0 … 3); rest and starting poses with every cube in its own cell; a target
// of as many distinct cells (sorted); the orientations the match allows (`fixed`, `upright`, `any`); a starting pose that
// does not already match; an action budget 1 … 40; a difficulty 1 … 5 and whether a tutorial precedes play. Its
// fingerprint is the SHA-256 hex of its canonical JSON (schema 1, sorted keys, fingerprint excluded); the stored form is
// re-checked on decode. Cubes, hinges and progress are named in words (FR-R02G1501-013); cube and hinge numbers are their
// indices (hinge i joins cube i to its parent). Modelled on `MoonlitMechanismLevel` (feature 431).
import Foundation
import VisualCoreMath

/// The truth metric after an action (clarification Q4): occupancy, the canonical hash of the occupied cells, the most
/// cubes an allowed alignment of the target covers, and whether the occupied cells match the target. It never decides
/// by itself.
public struct VoxelOrigamiShapeReport: Sendable, Equatable {
    /// Whether no cell holds two cubes.
    public let occupancy: Bool
    /// The canonical hash of the occupied cells under the level's group.
    public let hash: String
    /// The most cubes one allowed rotation and translation of the target covers.
    public let covered: Int
    /// Whether the occupied cells' canonical form equals the target's.
    public let matched: Bool
}

/// An immutable, fingerprinted Voxel Origami level.
public struct VoxelOrigamiLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema: Int = 1
    /// The difficulty range.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The cube count range.
    public static let cubeCounts: ClosedRange<Int> = 4...12
    /// The budget range.
    public static let budgets: ClosedRange<Int> = 1...40

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The cubes, root first.
    public let cubes: [VoxelOrigamiCube]
    /// The target cells, sorted and distinct, one per cube.
    public let target: [VoxelOrigamiVector]
    /// The orientations the match allows.
    public let orientations: VoxelOrigamiOrientations
    /// The action budget, 1 … 40.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON content.
    public let fingerprint: String
    /// The canonical form of the target under the allowed group.
    public let targetCanonical: [VoxelOrigamiVector]

    /// A level of the given values, checked.
    ///
    /// - Throws: `.level(name)` naming the first value outside its range or rule.
    public init(id: String, seed: UInt64, difficulty: Int, cubes: [VoxelOrigamiCube], target: [VoxelOrigamiVector],
                orientations: VoxelOrigamiOrientations, budget: Int,
                tutorial: Bool = false) throws(VoxelOrigamiError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.cubeCounts.contains(cubes.count) else { throw .level("cubes") }
        for (index, cube) in cubes.enumerated() {
            if index == 0 {
                guard cube == .root else { throw .level("root") }
            } else {
                guard let parent = cube.parent, parent >= 0, parent < index else { throw .level("parent") }
                guard cube.direction.isUnit else { throw .level("direction") }
                guard (0...3).contains(cube.startTurn) else { throw .level("turn") }
            }
        }
        let rest: VoxelOrigamiPose = VoxelOrigamiLattice.pose(cubes, turns: Array(repeating: 0, count: cubes.count))
        guard rest.isCollisionFree else { throw .level("rest") }
        let start: VoxelOrigamiPose = VoxelOrigamiLattice.pose(cubes, turns: cubes.map(\.startTurn))
        guard start.isCollisionFree else { throw .level("start") }
        guard target.count == cubes.count, Self.isSortedDistinct(target) else { throw .level("target") }
        let group: [VoxelOrigamiRotation] = orientations.group
        let canonicalTarget: [VoxelOrigamiVector] = VoxelOrigamiLattice.canonical(target, group: group)
        guard VoxelOrigamiLattice.canonical(start.cells, group: group) != canonicalTarget else {
            throw .level("solved")
        }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, cubes: cubes,
                              target: target, orientations: orientations, budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.cubes = cubes
        self.target = target
        self.orientations = orientations
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
        self.targetCanonical = canonicalTarget
    }

    /// The number of hinges (one per non-root cube).
    public var hingeCount: Int { cubes.count - 1 }

    /// The starting quarter turns, one per cube (0 for the root).
    public var startTurns: [Int] { cubes.map(\.startTurn) }

    /// The pose at `turns`.
    public func pose(turns: [Int]) -> VoxelOrigamiPose { VoxelOrigamiLattice.pose(cubes, turns: turns) }

    /// The truth metric at `turns` (clarification Q4).
    public func report(turns: [Int]) -> VoxelOrigamiShapeReport {
        let current: VoxelOrigamiPose = pose(turns: turns)
        let group: [VoxelOrigamiRotation] = orientations.group
        let occupied: [VoxelOrigamiVector] = current.occupied
        let covered = VoxelOrigamiLattice.covered(target: target, occupied: occupied, group: group)
        return VoxelOrigamiShapeReport(occupancy: current.isCollisionFree,
                                       hash: VoxelOrigamiLattice.canonicalHash(occupied, group: group),
                                       covered: covered.count,
                                       matched: VoxelOrigamiLattice.canonical(occupied, group: group)
                                           == targetCanonical)
    }

    /// Whether hinge `hinge` would swing at least one cube at `turns` (a leaf, or a hinge whose descendants all lie on
    /// its axis, would not).
    public func canTurn(_ hinge: Int, turns: [Int]) -> Bool {
        guard hinge >= 1, hinge < cubes.count else { return false }
        return !VoxelOrigamiLattice.swinging(cubes, pose: pose(turns: turns), hinge: hinge).isEmpty
    }

    /// "cube 3".
    public func cubeName(_ index: Int) -> String { "cube \(index)" }

    /// "hinge 3, turned 90 degrees".
    public func hingeName(_ hinge: Int, turn: Int) -> String {
        "hinge \(hinge), turned \((((turn % 4) + 4) % 4) * 90) degrees"
    }

    /// The progress in words: the cubes in place of the target, whether the shape matches, and the actions left.
    public func progressDescription(report: VoxelOrigamiShapeReport, actionsLeft: Int) -> String {
        var parts: [String] = ["\(report.covered) of \(cubes.count) cubes in place"]
        parts.append(report.matched ? "the shape matches the target" : "the shape does not match yet")
        if !report.occupancy { parts.append("two cubes share a cell") }
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// Whether `cells` are strictly increasing.
    static func isSortedDistinct(_ cells: [VoxelOrigamiVector]) -> Bool {
        var previous: VoxelOrigamiVector? = nil
        for cell in cells {
            if let last = previous, !(last < cell) { return false }
            previous = cell
        }
        return true
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Voxel Origami level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: VoxelOrigamiLevel
        do {
            level = try stored.content.level()
        } catch {
            throw .malformed(error.reasonCode)
        }
        guard level.fingerprint == stored.fingerprint else { throw .malformed("fingerprint") }
        return level
    }

    /// JSON with sorted keys.
    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// Whether `id` is a lowercase slug of 1 … 64 characters: a … z, 0 … 9 and single inner hyphens.
    static func isSlug(_ id: String) -> Bool {
        let scalars = Array(id.unicodeScalars)
        guard !scalars.isEmpty, scalars.count <= 64, scalars.first != "-", scalars.last != "-" else { return false }
        var previousHyphen = false
        for s in scalars {
            let hyphen = s == "-"
            guard hyphen || ("a"..."z").contains(s) || ("0"..."9").contains(s) else { return false }
            if hyphen && previousHyphen { return false }
            previousHyphen = hyphen
        }
        return true
    }

    /// The fingerprinted content.
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let cubes: [VoxelOrigamiCube]
        let target: [VoxelOrigamiVector]
        let orientations: VoxelOrigamiOrientations
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, cubes: [VoxelOrigamiCube],
             target: [VoxelOrigamiVector], orientations: VoxelOrigamiOrientations, budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.cubes = cubes
            self.target = target
            self.orientations = orientations
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: VoxelOrigamiLevel) {
            self.init(schema: VoxelOrigamiLevel.schema, id: level.id, seed: level.seed, difficulty: level.difficulty,
                      cubes: level.cubes, target: level.target, orientations: level.orientations,
                      budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
            try VoxelOrigamiLevel(id: id, seed: seed, difficulty: difficulty, cubes: cubes, target: target,
                                  orientations: orientations, budget: budget, tutorial: tutorial)
        }
    }

    /// The stored form: the content flattened with its fingerprint.
    struct Stored: Codable {
        let content: Content
        let fingerprint: String

        init(content: Content, fingerprint: String) {
            self.content = content
            self.fingerprint = fingerprint
        }

        private enum Keys: String, CodingKey { case fingerprint }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            fingerprint = try c.decode(String.self, forKey: .fingerprint)
            content = try Content(from: decoder)
        }

        func encode(to encoder: any Encoder) throws {
            try content.encode(to: encoder)
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(fingerprint, forKey: .fingerprint)
        }
    }
}

extension VoxelOrigamiLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = VoxelOrigamiError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = VoxelOrigamiError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
