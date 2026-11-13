// SampleExperienceCore — feature 188 T-U02-014 (FR-U02-072; data-model section 7; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-core-api.md, section "Sample"). The experience that exists
// only for tests: a 16 × 16 board with a marker, a target and a moving phase. A marker type chooses one deliberate
// fault, so that the tests can prove that each conformance check finds the fault it is meant to find.
// Test-only (rule R5): no app and no shipped module depends on this file.
import Foundation
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

// MARK: - Faults

/// The deliberate faults of the sample experience.
public enum SampleFaultKind: String, Sendable, CaseIterable {
    /// The sample keeps every obligation of the contract.
    case none
    /// The preparation mixes the uptime clock into the seed.
    case unseededPreparation
    /// The snapshot loses `tone`.
    case lossySnapshot
    /// The reset keeps what the player changed.
    case wrongReset
    /// A rule rejection adds to `energy` before it rejects.
    case mutatingRejection
    /// Setting the quality tier writes the tier into `energy`.
    case tierChangesState
    /// Shedding the caches changes `energy`.
    case sheddingChangesState
    /// The update mixes the uptime clock into `phase`.
    case clockInUpdate
    /// The preparation sleeps in small slices for about 60 seconds.
    case slowPreparation
    /// The preparation throws the failure `sample.broken`.
    case failingPreparation
    /// The quality profile has two levels while the core declares three tiers.
    case wrongProfileCount
}

/// A marker type that chooses the fault of a `SampleExperienceCore`.
public protocol SampleFault: Sendable {
    /// The fault the marker stands for.
    static var kind: SampleFaultKind { get }
}

/// The sample without a fault.
public enum NoFault: SampleFault {
    /// `.none`.
    public static var kind: SampleFaultKind { .none }
}

/// The sample that prepares from the seed mixed with the uptime clock.
public enum UnseededPreparation: SampleFault {
    /// `.unseededPreparation`.
    public static var kind: SampleFaultKind { .unseededPreparation }
}

/// The sample whose snapshot loses `tone`.
public enum LossySnapshot: SampleFault {
    /// `.lossySnapshot`.
    public static var kind: SampleFaultKind { .lossySnapshot }
}

/// The sample whose reset keeps what the player changed.
public enum WrongReset: SampleFault {
    /// `.wrongReset`.
    public static var kind: SampleFaultKind { .wrongReset }
}

/// The sample that changes its state before it rejects an action by a rule.
public enum MutatingRejection: SampleFault {
    /// `.mutatingRejection`.
    public static var kind: SampleFaultKind { .mutatingRejection }
}

/// The sample whose quality tier changes the domain state.
public enum TierChangesState: SampleFault {
    /// `.tierChangesState`.
    public static var kind: SampleFaultKind { .tierChangesState }
}

/// The sample whose cache shedding changes the domain state.
public enum SheddingChangesState: SampleFault {
    /// `.sheddingChangesState`.
    public static var kind: SampleFaultKind { .sheddingChangesState }
}

/// The sample whose update reads the uptime clock.
public enum ClockInUpdate: SampleFault {
    /// `.clockInUpdate`.
    public static var kind: SampleFaultKind { .clockInUpdate }
}

/// The sample whose preparation takes about 60 seconds unless it is cancelled.
public enum SlowPreparation: SampleFault {
    /// `.slowPreparation`.
    public static var kind: SampleFaultKind { .slowPreparation }
}

/// The sample whose preparation always fails.
public enum FailingPreparation: SampleFault {
    /// `.failingPreparation`.
    public static var kind: SampleFaultKind { .failingPreparation }
}

/// The sample whose quality profile has fewer levels than it declares tiers.
public enum WrongProfileCount: SampleFault {
    /// `.wrongProfileCount`.
    public static var kind: SampleFaultKind { .wrongProfileCount }
}

// MARK: - Start state

/// The running values of the preparation: one `SplitMix64` and five accumulators, mixed once per round.
private struct SampleStart {
    static let rounds = 256

    private var generator: SplitMix64
    private var a: UInt64 = 0, b: UInt64 = 0, c: UInt64 = 0, d: UInt64 = 0, e: UInt64 = 0

    init(seed: UInt64) { generator = SplitMix64(seed: seed) }

    private static func rotated(_ value: UInt64, by count: UInt64) -> UInt64 {
        (value << count) | (value >> (64 - count))
    }

    /// One round: the next generator output goes into every accumulator. Integer arithmetic only.
    mutating func round() {
        let value = generator.next()
        a ^= value
        b = b &+ Self.rotated(value, by: 13)
        c ^= Self.rotated(value, by: 29)
        d = d &+ Self.rotated(value, by: 43)
        e ^= Self.rotated(value, by: 53)
    }

    /// The start values: positions 0…15 and the phase as an exact fraction of 1,024.
    var values: (x: Int, y: Int, targetX: Int, targetY: Int, phase: Double) {
        (Int(a % 16), Int(b % 16), Int(c % 16), Int(d % 16), Double(e % 1024) / 1024)
    }
}

// MARK: - Core

/// The core of the sample experience `a99.contract-sample`: a marker on a 16 × 16 board, a target, an energy
/// count, a tone and a phase that advances with every step. `Fault` chooses one deliberate fault; `NoFault` keeps
/// the whole contract.
///
/// Equality compares every stored field, the quality tier, the cache and the call counters included; compare
/// digests to compare domain states.
public struct SampleExperienceCore<Fault: SampleFault>: ExperienceCore, Codable, Equatable {
    /// The number of cells along each side of the board.
    public static var boardSize: Int { 16 }
    /// The largest value of `energy`.
    public static var maxEnergy: Int { 1_000_000 }

    /// The seed of the preparation, kept for the reset.
    public private(set) var seed: UInt64
    /// The column of the marker, 0…15.
    public private(set) var x: Int
    /// The row of the marker, 0…15.
    public private(set) var y: Int
    /// The column of the target, 0…15.
    public private(set) var targetX: Int
    /// The row of the target, 0…15.
    public private(set) var targetY: Int
    /// The number of accepted moves, at most 1,000,000. Added in schema version 2.
    public private(set) var energy: Int
    /// The tone set by the control `tone`, 0…1.
    public private(set) var tone: Double
    /// The phase, 0 ..< 1; it advances by `stepDuration × 0.5` per step.
    public private(set) var phase: Double
    /// The number of steps the core has seen.
    public private(set) var ticks: Int
    /// The quality tier. Not part of the digest.
    public private(set) var tier: Int
    /// A cache that is rebuilt on demand. Not part of the digest.
    public private(set) var cache: [Int]
    /// How often `apply` was called on this value. Not part of the digest and not stored in a snapshot.
    public private(set) var applyCalls: Int
    /// How often `update` was called on this value. Not part of the digest and not stored in a snapshot.
    public private(set) var updateCalls: Int

    // MARK: Static requirements

    /// Schema version 2; the step from version 1 adds `"energy": 0`.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 2, steps: [1: { payload in
            var migrated = payload
            migrated["energy"] = 0
            return migrated
        }])
    }

    /// `move` (two values in −1…1), `tone` (one value in 0…1) and `ping` (no values).
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "move", ranges: [-1.0...1.0, -1.0...1.0]),
         ExperienceControl(id: "tone", ranges: [0.0...1.0]),
         ExperienceControl(id: "ping", ranges: [])]
    }

    /// Three quality tiers.
    public static var qualityTiers: Int { 3 }
    /// The three levels `full`, `reduced` and `minimal` with falling budgets; the fault `wrongProfileCount` leaves
    /// the last one out.
    public static var qualityProfile: QualityProfile {
        let levels = [QualityLevel(name: "full", resolutionShare: 1, elementShare: 1, iterationShare: 1, effectPasses: 2),
                      QualityLevel(name: "reduced", resolutionShare: 0.75, elementShare: 0.6, iterationShare: 0.5,
                                   effectPasses: 1),
                      QualityLevel(name: "minimal", resolutionShare: 0.5, elementShare: 0.35, iterationShare: 0.25,
                                   effectPasses: 0)]
        let declared = Fault.kind == .wrongProfileCount ? Array(levels.dropLast()) : levels
        return (try? QualityProfile(levels: declared)) ?? .uniform(levels: declared.count)
    }
    /// 1/120 s.
    public static var stepDuration: Double { 1.0 / 120 }

    // MARK: Preparation

    private init(seed: UInt64, start: (x: Int, y: Int, targetX: Int, targetY: Int, phase: Double)) {
        self.seed = seed
        x = start.x
        y = start.y
        targetX = start.targetX
        targetY = start.targetY
        energy = 0
        tone = 0
        phase = start.phase
        ticks = 0
        tier = 0
        cache = []
        applyCalls = 0
        updateCalls = 0
    }

    /// The start values that belong to `seed`: 256 rounds of `SplitMix64`, integer arithmetic only, no clock.
    private static func start(seed: UInt64) -> (x: Int, y: Int, targetX: Int, targetY: Int, phase: Double) {
        var running = SampleStart(seed: seed)
        for _ in 0..<SampleStart.rounds { running.round() }
        return running.values
    }

    /// Derives every start value from `seed` in 256 rounds and checks for cancellation between the rounds. The
    /// result equals the state a reset returns to. The faults `unseededPreparation`, `slowPreparation` and
    /// `failingPreparation` act here.
    public static func prepare(seed: UInt64) async throws -> Self {
        var usedSeed = seed
        switch Fault.kind {
        case .failingPreparation:
            throw ExperienceFailure(code: "sample.broken", message: "the sample was asked to fail")
        case .unseededPreparation:
            usedSeed = seed ^ DispatchTime.now().uptimeNanoseconds
        case .slowPreparation:
            for _ in 0..<6_000 { try await Task.sleep(for: .milliseconds(10)) }
        default:
            break
        }
        var running = SampleStart(seed: usedSeed)
        for _ in 0..<SampleStart.rounds {
            try Task.checkCancellation()
            running.round()
            await Task.yield()
        }
        try Task.checkCancellation()
        return Self(seed: usedSeed, start: running.values)
    }

    // MARK: Rules

    /// Advances the phase by `stepDuration × 0.5` (wrapped into 0 ..< 1), counts the step and rebuilds the cache
    /// when it is empty. The fault `clockInUpdate` acts here.
    public mutating func update(step: Int) {
        updateCalls += 1
        phase += Self.stepDuration * 0.5
        if Fault.kind == .clockInUpdate {
            phase += Double(DispatchTime.now().uptimeNanoseconds % 1000) / 1_000_000
        }
        if phase >= 1 { phase -= 1 }
        ticks += 1
        if cache.isEmpty {
            cache = (0..<(4 * (tier + 1))).map { index in x * 31 + y * 17 + index }
        }
    }

    /// `move` rounds each value to −1, 0 or 1 and moves the marker (rule codes `sample.no-move` for 0, 0 and
    /// `sample.wall` for a move that would leave the board); `tone` sets the tone; `ping` changes nothing. The
    /// fault `mutatingRejection` acts here.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        applyCalls += 1
        switch action.control {
        case "move":
            guard action.values.count == 2 else {
                return .rejected(.wrongValueCount(expected: 2, found: action.values.count))
            }
            guard action.values[0].isFinite else { return .rejected(.nonFinite(index: 0)) }
            guard action.values[1].isFinite else { return .rejected(.nonFinite(index: 1)) }
            let dx = Self.direction(action.values[0]), dy = Self.direction(action.values[1])
            guard dx != 0 || dy != 0 else { return ruleRejection("sample.no-move") }
            let cells = 0..<Self.boardSize
            guard cells.contains(x + dx), cells.contains(y + dy) else { return ruleRejection("sample.wall") }
            x += dx
            y += dy
            energy = min(energy + 1, Self.maxEnergy)
            return .accepted
        case "tone":
            guard action.values.count == 1 else {
                return .rejected(.wrongValueCount(expected: 1, found: action.values.count))
            }
            guard action.values[0].isFinite else { return .rejected(.nonFinite(index: 0)) }
            guard (0.0...1.0).contains(action.values[0]) else { return .rejected(.outOfRange(index: 0)) }
            tone = action.values[0]
            return .accepted
        case "ping":
            return .accepted
        default:
            return .rejected(.unknownControl(action.control))
        }
    }

    /// A finite value rounded to −1, 0 or 1.
    private static func direction(_ value: Double) -> Int {
        Int(max(-1, min(1, value.rounded())))
    }

    /// The rejection by a rule of the sample; the fault `mutatingRejection` adds to `energy` first.
    private mutating func ruleRejection(_ code: String) -> ActionResult {
        if Fault.kind == .mutatingRejection { energy += 1 }
        return .rejected(.rule(code: code))
    }

    /// Returns to the state of a fresh preparation with the stored seed. The quality tier stays and the cache is
    /// dropped. The fault `wrongReset` acts here.
    public mutating func reset() {
        let start = Self.start(seed: seed)
        x = start.x
        y = start.y
        targetX = start.targetX
        targetY = start.targetY
        phase = start.phase
        ticks = 0
        cache = []
        if Fault.kind != .wrongReset {
            energy = 0
            tone = 0
        }
    }

    /// Stores the tier and drops the cache. The fault `tierChangesState` acts here.
    public mutating func setQualityTier(_ tier: Int) {
        self.tier = tier
        cache = []
        if Fault.kind == .tierChangesState { energy = tier }
    }

    /// Drops the cache. The fault `sheddingChangesState` acts here.
    public mutating func shedCaches() {
        cache = []
        if Fault.kind == .sheddingChangesState { energy += 1 }
    }

    // MARK: Outcome

    /// `target-reached` while the marker stands on the target, otherwise nil (feature 195, UA-F09). Derived from
    /// `x`, `y`, `targetX` and `targetY` when asked; nothing is stored, so the digest and the snapshot are unchanged.
    public var outcome: ExperienceOutcome? {
        guard x == targetX, y == targetY else { return nil }
        return ExperienceOutcome(code: "target-reached")
    }

    // MARK: Digest

    /// Adds seed, x, y, targetX, targetY, energy, tone, phase and ticks, in this order. The tier, the cache and
    /// the call counters stay out.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(seed)
        builder.add(x)
        builder.add(y)
        builder.add(targetX)
        builder.add(targetY)
        builder.add(energy)
        try builder.add(tone)
        try builder.add(phase)
        builder.add(ticks)
    }

    // MARK: Snapshot

    private enum CodingKeys: String, CodingKey {
        case seed, x, y, targetX, targetY, energy, tone, phase, ticks, tier, cache
    }

    /// Decodes a payload of schema version 2. `seed` is decimal text (a plain number is read too); `tier` and
    /// `cache` may be missing; the call counters start at 0.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .seed) {
            guard let value = UInt64(text) else {
                throw DecodingError.dataCorruptedError(forKey: .seed, in: container,
                                                       debugDescription: "the seed is not a 64-bit decimal number")
            }
            seed = value
        } else {
            seed = try container.decode(UInt64.self, forKey: .seed)
        }
        x = try container.decode(Int.self, forKey: .x)
        y = try container.decode(Int.self, forKey: .y)
        targetX = try container.decode(Int.self, forKey: .targetX)
        targetY = try container.decode(Int.self, forKey: .targetY)
        energy = try container.decode(Int.self, forKey: .energy)
        tone = try container.decode(Double.self, forKey: .tone)
        phase = try container.decode(Double.self, forKey: .phase)
        ticks = try container.decode(Int.self, forKey: .ticks)
        tier = try container.decodeIfPresent(Int.self, forKey: .tier) ?? 0
        cache = try container.decodeIfPresent([Int].self, forKey: .cache) ?? []
        applyCalls = 0
        updateCalls = 0
    }

    /// Encodes every field except the call counters. `seed` is written as decimal text, because a migration reads
    /// the payload with `JSONSerialization` and a 64-bit number has to survive that exactly.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(seed), forKey: .seed)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(targetX, forKey: .targetX)
        try container.encode(targetY, forKey: .targetY)
        try container.encode(energy, forKey: .energy)
        try container.encode(tone, forKey: .tone)
        try container.encode(phase, forKey: .phase)
        try container.encode(ticks, forKey: .ticks)
        try container.encode(tier, forKey: .tier)
        try container.encode(cache, forKey: .cache)
    }

    /// The core as JSON with keys in sorted order. The fault `lossySnapshot` writes `tone` as 0.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard Fault.kind == .lossySnapshot else { return try encoder.encode(self) }
        var lossy = self
        lossy.tone = 0
        return try encoder.encode(lossy)
    }

    /// The core decoded from a payload of schema version 2; the seed is part of the payload.
    public static func restore(payload: Data, seed: UInt64) throws -> Self {
        try JSONDecoder().decode(Self.self, from: payload)
    }
}
