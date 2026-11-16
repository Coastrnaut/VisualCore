// SimulationSpec — feature 117 (A16-P01) T-A16-102 (FR-A16-110–112; SC-A16-103, SC-A16-104; clarifications Q1–Q4;
// data-model "SimulationSpec (schema 1)"; contracts/core.md). The versioned description of one simulation: its kind,
// grid size, time step, boundary rule, seed, parameter values and algorithm version.
//
// Written as JSON with sorted keys:
// `{"algorithmVersion": 1, "boundary": "wrap", "gridSize": 64, "kind": "automaton", "parameters": {"rule": 0},
// "schema": 1, "seed": "<decimal>", "timeStep": 1}`; the seed is a decimal string so every UInt64 survives exactly.
// `decode(_:)` refuses, in this order: `damaged` (not JSON, a missing or malformed key, a schema below 1),
// `unknownVersion` (a schema or algorithm version other than 1), `unknownKind`, `unknownBoundary` (an unknown
// boundary name), and then whatever `validated()` refuses.
//
// `validated()` checks, in this order:
// - the algorithm version is 1 (`unknownVersion`);
// - the grid size is 16, 32, 64, 128 or 256 (`invalidGridSize`; the experience of this phase uses 64 only);
// - the boundary is the family's (wrap for automata and reaction-diffusion, fixed zero for the wave; `unknownBoundary`);
// - the time step and every parameter value are finite (`nonFinite`);
// - the parameter names are exactly the family's (`unknownParameter`, `missingParameter`);
// - every parameter is within its definition, the automaton's rule a whole index (`outOfRange`);
// - stability: Gray-Scott Δt ≤ 1.5625 (Δt · 4 · max(Dᵤ, Dᵥ) ≤ 1) and the wave's Courant number c · Δt ≤ 1/√2
//   (`unstable`, the wave with the sentence "The wave step is too large: the Courant number must stay at or below
//   0.707.");
// - the time step is within its definition, and exactly 1 for the automaton (`outOfRange`).
// Each refusal carries a sentence that names the limit; a refused spec changes nothing.
import Foundation
import VisualCoreParameters
import VisualCoreSimulation

/// The three simulation families.
public enum SimulationKind: String, Codable, CaseIterable, Sendable {
    /// A two-state outer-totalistic cellular automaton (Moore neighbourhood, wrap boundary).
    case automaton
    /// Gray-Scott reaction-diffusion (five-point stencil, explicit Euler, wrap boundary).
    case reactionDiffusion
    /// A 2D wave field (leapfrog, five-point stencil, fixed zero border).
    case wave

    /// The user-facing name of the family.
    public var title: String {
        switch self {
        case .automaton: "cellular automaton"
        case .reactionDiffusion: "reaction-diffusion"
        case .wave: "wave field"
        }
    }

    /// The boundary rule of the family: wrap for automata and reaction-diffusion, fixed zero for the wave.
    public var boundary: BoundaryMode { self == .wave ? .fixedZero : .wrap }

    /// The storage precision of the field: `unorm8` for automata (exact 0 and 1), `float16` for the others.
    public var storagePrecision: StoragePrecision { self == .automaton ? .unorm8 : .float16 }

    /// The values per cell of the field: 1 (alive), 2 (u, v) or 1 (height; the wave also keeps the previous field).
    public var channels: Int { self == .reactionDiffusion ? 2 : 1 }

    /// The base rate in iterations per second at speed 1: 10 (automata), 240 (reaction-diffusion), 120 (wave).
    public var baseRate: Double {
        switch self {
        case .automaton: 10
        case .reactionDiffusion: 240
        case .wave: 120
        }
    }
}

/// How the field is continued beyond its edge.
public enum BoundaryMode: String, Codable, CaseIterable, Sendable {
    /// Opposite edges are neighbours (a torus).
    case wrap
    /// The outermost cells are held at zero.
    case fixedZero
}

/// Why a simulation spec (or a setting change) was refused, with a sentence for the person.
public struct SimulationRefusal: Error, Equatable, Sendable {
    /// The refusal reasons.
    public enum Reason: String, Codable, CaseIterable, Sendable {
        /// Not JSON, or a missing or malformed key.
        case damaged
        /// A schema or algorithm version other than 1.
        case unknownVersion = "unknown-version"
        /// An unknown simulation kind.
        case unknownKind = "unknown-kind"
        /// An unknown boundary, or a boundary the family does not use.
        case unknownBoundary = "unknown-boundary"
        /// A grid size outside 16, 32, 64, 128 and 256.
        case invalidGridSize = "invalid-grid-size"
        /// A parameter the family does not have.
        case unknownParameter = "unknown-parameter"
        /// A parameter of the family is not given.
        case missingParameter = "missing-parameter"
        /// A NaN or infinite value.
        case nonFinite = "non-finite"
        /// A value outside its definition's range.
        case outOfRange = "out-of-range"
        /// A time step beyond the family's stability limit.
        case unstable
    }

    /// The reason.
    public let reason: Reason
    /// A sentence that explains the refusal and names the limit.
    public let sentence: String

    /// Creates a refusal.
    public init(_ reason: Reason, _ sentence: String) {
        self.reason = reason
        self.sentence = sentence
    }

    /// The wave's Courant refusal, with the exact sentence of clarification Q3.
    public static let courant = SimulationRefusal(
        .unstable, "The wave step is too large: the Courant number must stay at or below 0.707.")
    /// The Gray-Scott time-step refusal.
    public static let reactionStep = SimulationRefusal(
        .unstable, "The reaction-diffusion step is too large: the time step must stay at or below 1.5625.")
    /// The refusal of an unreadable spec.
    public static let damaged = SimulationRefusal(.damaged, "The simulation settings are damaged and cannot be read.")
}

/// The versioned description of one simulation (schema 1).
public struct SimulationSpec: Codable, Equatable, Sendable {
    /// The spec schema this code reads and writes.
    public static let schemaVersion = 1
    /// The algorithm version this code implements.
    public static let currentAlgorithmVersion = 1
    /// The allowed grid sizes, in cells per side.
    public static let gridSizes = [16, 32, 64, 128, 256]
    /// The grid size of the standard specs (the CPU size of this phase's experience).
    public static let standardGridSize = 64
    /// The largest Courant number of the wave, 1/√2 (≈ 0.7071).
    public static let courantLimit = 1 / 2.0.squareRoot()
    /// The largest Gray-Scott time step, 1 / (4 · max(Dᵤ, Dᵥ)) = 1.5625.
    public static let reactionTimeStepLimit = 1.5625

    /// The family.
    public var kind: SimulationKind
    /// Cells per side.
    public var gridSize: Int
    /// The time step Δt (1 for the automaton).
    public var timeStep: Double
    /// The boundary rule.
    public var boundary: BoundaryMode
    /// The seed of the seeded start.
    public var seed: UInt64
    /// The parameter values by definition name (see `ParameterCatalog.definitions(for:)`).
    public var parameters: [String: Double]
    /// The algorithm version (1).
    public var algorithmVersion: Int

    /// Creates a spec (no validation; see `validated()`).
    public init(kind: SimulationKind, gridSize: Int, timeStep: Double, boundary: BoundaryMode, seed: UInt64,
                parameters: [String: Double], algorithmVersion: Int = SimulationSpec.currentAlgorithmVersion) {
        self.kind = kind
        self.gridSize = gridSize
        self.timeStep = timeStep
        self.boundary = boundary
        self.seed = seed
        self.parameters = parameters
        self.algorithmVersion = algorithmVersion
    }

    /// The standard spec of `kind` with preset `preset` (clamped into `ParameterCatalog.presetNames(for:)`) and
    /// `seed`: grid 64, the family's boundary and default time step. Always valid.
    public static func standard(_ kind: SimulationKind, preset: Int = 0, seed: UInt64 = 1) -> SimulationSpec {
        SimulationSpec(kind: kind, gridSize: standardGridSize, timeStep: ParameterCatalog.defaultTimeStep(for: kind),
                       boundary: kind.boundary, seed: seed,
                       parameters: ParameterCatalog.presetParameters(for: kind, preset: preset))
    }

    /// The value of parameter `name`, or its default when absent (0 for an unknown name).
    public func value(_ name: String) -> Double {
        parameters[name] ?? ParameterCatalog.definitions(for: kind).first { $0.name == name }?.defaultValue ?? 0
    }

    /// The wave's Courant number c · Δt (Δx = 1); 0 for the other families.
    public var courantNumber: Double { kind == .wave ? value(ParameterCatalog.speed.name) * timeStep : 0 }

    /// The automaton rule of this spec (Life for the other families or an invalid index).
    public var automatonRule: AutomatonRule {
        let index = Int(value(ParameterCatalog.rule.name))
        return AutomatonRule.presets.indices.contains(index) ? AutomatonRule.presets[index] : .life
    }

    /// This spec when every check of the file header passes, else the first refusal.
    public func validated() -> Result<SimulationSpec, SimulationRefusal> {
        if let refusal = refusal() { return .failure(refusal) }
        return .success(self)
    }

    /// The first refusal of `validated()`, or nil for a valid spec.
    public func refusal() -> SimulationRefusal? {
        guard algorithmVersion == Self.currentAlgorithmVersion else {
            return SimulationRefusal(.unknownVersion, "These simulation settings use algorithm version "
                                     + "\(algorithmVersion); only version 1 is understood.")
        }
        guard Self.gridSizes.contains(gridSize) else {
            return SimulationRefusal(.invalidGridSize, "The grid size must be 16, 32, 64, 128 or 256 cells per side.")
        }
        guard boundary == kind.boundary else {
            let name = kind.boundary == .wrap ? "wrap" : "fixed zero"
            return SimulationRefusal(.unknownBoundary, "The \(kind.title) needs the \(name) boundary.")
        }
        let definitions = ParameterCatalog.definitions(for: kind)
        guard timeStep.isFinite else { return SimulationRefusal(.nonFinite, "The time step must be a finite number.") }
        for name in parameters.keys.sorted() {
            guard let definition = definitions.first(where: { $0.name == name }) else {
                return SimulationRefusal(.unknownParameter,
                                         "The parameter \"\(name)\" does not belong to the \(kind.title).")
            }
            guard parameters[name]?.isFinite == true else {
                return SimulationRefusal(.nonFinite, "The \(definition.title.lowercased()) must be a finite number.")
            }
        }
        for definition in definitions {
            guard let v = parameters[definition.name] else {
                return SimulationRefusal(.missingParameter, "The parameter \"\(definition.name)\" is missing.")
            }
            guard definition.range.contains(v) else { return Self.rangeRefusal(definition) }
            if definition.name == ParameterCatalog.rule.name, v.rounded() != v {
                return SimulationRefusal(.outOfRange, "The rule must be a whole number from 0 to 2.")
            }
        }
        switch kind {
        case .automaton:
            guard timeStep == 1 else {
                return SimulationRefusal(.outOfRange,
                                         "The cellular automaton advances one generation per step: its time step must be 1.")
            }
        case .reactionDiffusion:
            guard timeStep <= Self.reactionTimeStepLimit else { return .reactionStep }
            guard ParameterCatalog.reactionTimeStep.range.contains(timeStep) else {
                return Self.rangeRefusal(ParameterCatalog.reactionTimeStep)
            }
        case .wave:
            guard courantNumber <= Self.courantLimit * (1 + 1e-12) else { return .courant }
            guard ParameterCatalog.waveTimeStep.range.contains(timeStep) else {
                return Self.rangeRefusal(ParameterCatalog.waveTimeStep)
            }
        }
        return nil
    }

    /// The out-of-range refusal of `definition`, naming its range.
    static func rangeRefusal(_ definition: ParameterDefinition) -> SimulationRefusal {
        SimulationRefusal(.outOfRange, "The \(definition.title.lowercased()) must stay within "
                          + "\(definition.minimum) to \(definition.maximum).")
    }

    // MARK: Codec

    private enum CodingKeys: String, CodingKey {
        case algorithmVersion, boundary, gridSize, kind, parameters, schema, seed, timeStep
    }

    /// Writes the schema-1 JSON of the file header.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(algorithmVersion, forKey: .algorithmVersion)
        try c.encode(boundary.rawValue, forKey: .boundary)
        try c.encode(gridSize, forKey: .gridSize)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encode(parameters, forKey: .parameters)
        try c.encode(String(seed), forKey: .seed)
        try c.encode(timeStep, forKey: .timeStep)
    }

    /// Reads and validates a schema-1 spec; throws a `SimulationRefusal` (a decoding error reads as `damaged` in
    /// `decode(_:)`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let schema = try? c.decode(Int.self, forKey: .schema), schema >= 1 else { throw SimulationRefusal.damaged }
        guard schema == Self.schemaVersion else {
            throw SimulationRefusal(.unknownVersion, "These simulation settings use schema \(schema); only schema 1 "
                                    + "is understood.")
        }
        guard let version = try? c.decode(Int.self, forKey: .algorithmVersion),
              let kindName = try? c.decode(String.self, forKey: .kind),
              let boundaryName = try? c.decode(String.self, forKey: .boundary),
              let gridSize = try? c.decode(Int.self, forKey: .gridSize),
              let timeStep = try? c.decode(Double.self, forKey: .timeStep),
              let seedText = try? c.decode(String.self, forKey: .seed), let seed = UInt64(seedText),
              let parameters = try? c.decode([String: Double].self, forKey: .parameters) else {
            throw SimulationRefusal.damaged
        }
        guard version == Self.currentAlgorithmVersion else {
            throw SimulationRefusal(.unknownVersion, "These simulation settings use algorithm version \(version); "
                                    + "only version 1 is understood.")
        }
        guard let kind = SimulationKind(rawValue: kindName) else {
            throw SimulationRefusal(.unknownKind, "The simulation kind \"\(kindName)\" is not known.")
        }
        guard let boundary = BoundaryMode(rawValue: boundaryName) else {
            throw SimulationRefusal(.unknownBoundary, "The boundary \"\(boundaryName)\" is not known.")
        }
        self.init(kind: kind, gridSize: gridSize, timeStep: timeStep, boundary: boundary, seed: seed,
                  parameters: parameters, algorithmVersion: version)
        if let refusal = refusal() { throw refusal }
    }

    /// A JSON encoder with sorted keys.
    static func sortedEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    /// The spec as JSON with sorted keys.
    public func encoded() -> Data { (try? Self.sortedEncoder().encode(self)) ?? Data() }

    /// The valid spec in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<SimulationSpec, SimulationRefusal> {
        do {
            return .success(try JSONDecoder().decode(SimulationSpec.self, from: data))
        } catch let refusal as SimulationRefusal {
            return .failure(refusal)
        } catch {
            return .failure(.damaged)
        }
    }
}
