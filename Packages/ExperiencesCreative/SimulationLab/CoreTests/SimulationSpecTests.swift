// SimulationSpecTests — feature 117 (A16-P01) T-A16-102 (FR-A16-110–112; SC-A16-103, SC-A16-104; clarifications
// Q1–Q4). The versioned spec, host-free and short: the schema-1 round trip is exact; unknown versions, kinds,
// boundaries and grid sizes are refused; every range edge is accepted and just beyond it refused; the stability limits
// accept the limit and refuse 1 % above it (the wave with the exact sentence); non-finite values are refused; the same
// seed gives the same start, seeds 0 and UInt64.max included.
import Foundation
import Testing
import VisualCoreParameters
import VisualCoreSimulation
@testable import SimulationLabCore

/// `data` as a JSON object changed by `change`, written back with sorted keys.
func mutatedJSON(_ data: Data, _ change: (inout [String: Any]) -> Void) -> Data {
    var object = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    change(&object)
    return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
}

@Suite struct SimulationSpecTests {
    /// The refusal reason of `spec`, or nil when valid.
    private func reason(_ spec: SimulationSpec) -> SimulationRefusal.Reason? { spec.refusal()?.reason }

    @Test func theStandardSpecsAreValidAndRoundTripExactly() {
        let seeds: [UInt64] = [0, 1, 42, UInt64.max]
        for kind in SimulationKind.allCases {
            for preset in 0..<ParameterCatalog.presetNames(for: kind).count {
                for seed in seeds {
                    let spec = SimulationSpec.standard(kind, preset: preset, seed: seed)
                    #expect(spec.refusal() == nil, "\(kind) \(preset)")
                    #expect(spec.gridSize == 64 && spec.boundary == kind.boundary && spec.algorithmVersion == 1)
                    let data = spec.encoded()
                    let decoded = SimulationSpec.decode(data)
                    #expect(decoded == .success(spec), "\(kind) \(preset) \(seed)")
                    if case .success(let back) = decoded { #expect(back.encoded() == data) }
                }
            }
        }
    }

    @Test func theJSONHasSortedKeysAndADecimalSeed() throws {
        let spec = SimulationSpec.standard(.automaton, preset: 1, seed: UInt64.max)
        let text = try #require(String(data: spec.encoded(), encoding: .utf8))
        #expect(text == #"{"algorithmVersion":1,"boundary":"wrap","gridSize":64,"kind":"automaton","#
                + #""parameters":{"rule":1},"schema":1,"seed":"18446744073709551615","timeStep":1}"#)
    }

    @Test func presetsCarryTheirValues() {
        #expect(ParameterCatalog.presetNames(for: .automaton) == ["Life", "HighLife", "Seeds"])
        #expect(ParameterCatalog.presetNames(for: .reactionDiffusion) == ["Spots", "Mazes"])
        #expect(ParameterCatalog.presetNames(for: .wave) == ["Pulse"])
        #expect(SimulationSpec.standard(.automaton, preset: 2).automatonRule == .seeds)
        let spots = SimulationSpec.standard(.reactionDiffusion, preset: 0)
        #expect(spots.parameters == ["feed": 0.035, "kill": 0.065] && spots.timeStep == 1.0)
        let mazes = SimulationSpec.standard(.reactionDiffusion, preset: 1)
        #expect(mazes.parameters == ["feed": 0.029, "kill": 0.057])
        let wave = SimulationSpec.standard(.wave)
        #expect(wave.parameters == ["speed": 1, "damping": 0.002] && wave.timeStep == 0.5 && wave.courantNumber == 0.5)
        #expect(SimulationSpec.standard(.automaton, preset: 9).automatonRule == .seeds)
        #expect(SimulationSpec.standard(.automaton, preset: -4).automatonRule == .life)
    }

    @Test func unknownVersionsKindsBoundariesAndGridSizesAreRefused() {
        let data = SimulationSpec.standard(.reactionDiffusion).encoded()
        let newer = mutatedJSON(data) { $0["schema"] = 2 }
        #expect(SimulationSpec.decode(newer).refusalReason == .unknownVersion)
        let algorithm = mutatedJSON(data) { $0["algorithmVersion"] = 2 }
        #expect(SimulationSpec.decode(algorithm).refusalReason == .unknownVersion)
        let kind = mutatedJSON(data) { $0["kind"] = "fluid" }
        #expect(SimulationSpec.decode(kind).refusalReason == .unknownKind)
        let boundary = mutatedJSON(data) { $0["boundary"] = "mirror" }
        #expect(SimulationSpec.decode(boundary).refusalReason == .unknownBoundary)
        let wrongBoundary = mutatedJSON(data) { $0["boundary"] = "fixedZero" }
        #expect(SimulationSpec.decode(wrongBoundary).refusalReason == .unknownBoundary)
        let damagedInputs: [Data] = [Data("not json".utf8), Data("{}".utf8), data.prefix(data.count / 2),
                                     mutatedJSON(data) { $0["seed"] = 5 }, mutatedJSON(data) { $0["schema"] = 0 },
                                     mutatedJSON(data) { $0["seed"] = "-1" },
                                     mutatedJSON(data) { $0.removeValue(forKey: "parameters") }]
        for input in damagedInputs { #expect(SimulationSpec.decode(input).refusalReason == .damaged) }

        var spec = SimulationSpec.standard(.wave)
        for size in SimulationSpec.gridSizes {
            spec.gridSize = size
            #expect(reason(spec) == nil, "\(size)")
        }
        let refusedSizes: [Int] = [0, 8, 48, 63, 65, 512, -64]
        for size in refusedSizes {
            spec.gridSize = size
            #expect(reason(spec) == .invalidGridSize, "\(size)")
        }
        var wave = SimulationSpec.standard(.wave)
        wave.boundary = .wrap
        #expect(reason(wave) == .unknownBoundary)
        wave = SimulationSpec.standard(.wave)
        wave.algorithmVersion = 0
        #expect(reason(wave) == .unknownVersion)
    }

    @Test func everyParameterRangeEdgeIsAcceptedAndBeyondRefused() {
        let bases: [SimulationSpec] = [.standard(.automaton), .standard(.reactionDiffusion), .standard(.wave)]
        for base in bases {
            for definition in ParameterCatalog.definitions(for: base.kind) {
                var spec = base
                if base.kind == .wave { spec.timeStep = 0.35 }   // keeps c · Δt ≤ 0.7 at c = 2
                let accepted: [Double] = [definition.minimum, definition.maximum]
                for v in accepted {
                    spec.parameters[definition.name] = v
                    #expect(reason(spec) == nil, "\(definition.name) \(v)")
                }
                let beyond: [Double] = [definition.minimum - 1e-9, definition.maximum + 1e-9]
                for v in beyond {
                    spec.parameters[definition.name] = v
                    #expect(reason(spec) == .outOfRange, "\(definition.name) \(v)")
                    #expect(spec.refusal()?.sentence.contains("must stay within") == true)
                }
                let nonFinite: [Double] = [.nan, .infinity, -.infinity]
                for v in nonFinite {
                    spec.parameters[definition.name] = v
                    #expect(reason(spec) == .nonFinite, "\(definition.name) \(v)")
                }
            }
        }
        var automaton = SimulationSpec.standard(.automaton)
        automaton.parameters["rule"] = 1.5
        #expect(reason(automaton) == .outOfRange)
        automaton = SimulationSpec.standard(.automaton)
        automaton.timeStep = 0.5
        #expect(reason(automaton) == .outOfRange)
        automaton.timeStep = .nan
        #expect(reason(automaton) == .nonFinite)
        automaton = SimulationSpec.standard(.automaton)
        automaton.parameters["feed"] = 0.03
        #expect(reason(automaton) == .unknownParameter)
        automaton.parameters = [:]
        #expect(reason(automaton) == .missingParameter)
    }

    @Test func theTimeStepRangesAreChecked() {
        var rd = SimulationSpec.standard(.reactionDiffusion)
        let rdAccepted: [Double] = [0.1, 1, 1.5625]
        for dt in rdAccepted {
            rd.timeStep = dt
            #expect(reason(rd) == nil, "\(dt)")
        }
        rd.timeStep = 0.0999
        #expect(reason(rd) == .outOfRange)
        var wave = SimulationSpec.standard(.wave)
        wave.parameters["speed"] = 0.5
        let waveAccepted: [Double] = [0.05, 0.5, 1]
        for dt in waveAccepted {
            wave.timeStep = dt
            #expect(reason(wave) == nil, "\(dt)")
        }
        let waveRefused: [Double] = [0.0499, 1.0001]
        for dt in waveRefused {
            wave.timeStep = dt
            #expect(reason(wave) == .outOfRange, "\(dt)")
        }
    }

    @Test func theStabilityLimitsAcceptTheLimitAndRefuseOnePercentAbove() {
        var rd = SimulationSpec.standard(.reactionDiffusion)
        rd.timeStep = 1.5625
        #expect(reason(rd) == nil)
        rd.timeStep = 1.5625 * 1.01
        #expect(rd.refusal() == SimulationRefusal.reactionStep && reason(rd) == .unstable)
        #expect(abs(1.5625 * 4 * Double(max(GrayScott.diffusionU, GrayScott.diffusionV)) - 1) < 1e-6)

        var wave = SimulationSpec.standard(.wave)
        wave.timeStep = 1 / 2.0.squareRoot()
        #expect(reason(wave) == nil && abs(wave.courantNumber - 0.7071) < 1e-4)
        wave.timeStep = 1.01 / 2.0.squareRoot()
        #expect(wave.refusal()?.reason == .unstable)
        #expect(wave.refusal()?.sentence == "The wave step is too large: the Courant number must stay at or below 0.707.")
        wave = SimulationSpec.standard(.wave)
        wave.parameters["speed"] = 2
        wave.timeStep = 0.5
        #expect(wave.refusal() == .courant)
        let decoded = SimulationSpec.decode(mutatedJSON(SimulationSpec.standard(.wave).encoded()) { $0["timeStep"] = 0.8 })
        #expect(decoded.refusalReason == .unstable)
    }

    @Test func theCatalogDefinitionsMatchTheDataModel() {
        #expect(ParameterCatalog.rule.range == 0...2)
        #expect(ParameterCatalog.feed.range == 0...0.1 && ParameterCatalog.kill.range == 0...0.1)
        #expect(ParameterCatalog.speed.range == 0.1...2 && ParameterCatalog.damping.range == 0...0.05)
        #expect(ParameterCatalog.damping.defaultValue == 0.002)
        #expect(ParameterCatalog.reactionTimeStep.range == 0.1...1.5625)
        #expect(ParameterCatalog.waveTimeStep.range == 0.05...1)
        #expect(ParameterCatalog.timeStepDefinition(for: .automaton) == nil)
        for kind in SimulationKind.allCases {
            let schema = try? ParameterSchema(ParameterCatalog.definitions(for: kind))
            #expect(schema != nil)
            for definition in ParameterCatalog.definitions(for: kind) { #expect(!definition.title.isEmpty) }
        }
    }

    @Test func theSameSeedGivesTheSameStart() {
        let seeds: [UInt64] = [0, 7, UInt64.max]
        for kind in SimulationKind.allCases {
            for seed in seeds {
                var spec = SimulationSpec.standard(kind, seed: seed)
                spec.gridSize = 32
                let a = Seeding.start(for: spec), b = Seeding.start(for: spec)
                #expect(a == b && a.current.isFinite, "\(kind) \(seed)")
                #expect(a.current.width == 32 && a.current.channels == kind.channels)
                #expect(a.current == a.current.rounded(to: kind.storagePrecision))
                var other = spec
                other.seed = seed &+ 1
                #expect(Seeding.start(for: other) != a, "\(kind) \(seed)")
            }
        }
    }

    @Test func theSeededStartsHaveTheirStatedShape() {
        let automaton = Seeding.automatonStart(gridSize: 64, seed: 3)
        let density = Double(AutomatonRule.liveCount(automaton)) / 4096
        #expect(density > 0.2 && density < 0.3)
        #expect(automaton.values.allSatisfy { $0 == 0 || $0 == 1 })

        let rd = Seeding.reactionStart(gridSize: 16, seed: 3)
        var patchCells = 0
        for cell in 0..<256 {
            let u = rd.values[cell * 2], v = rd.values[cell * 2 + 1]
            #expect((u == 1 && v == 0) || (u == 0.5 && v == 0.25))
            if u == 0.5 { patchCells += 1 }
        }
        #expect(patchCells >= 16 && patchCells <= 96)

        let wave = Seeding.waveStart(gridSize: 16, seed: UInt64.max)
        var peak: Float = 0
        for y in 0..<16 {
            for x in 0..<16 {
                if x == 0 || y == 0 || x == 15 || y == 15 { #expect(wave[x, y, 0] == 0) }
                peak = max(peak, wave[x, y, 0])
            }
        }
        #expect(peak == 1)
        let start = Seeding.start(for: .standard(.wave, seed: 5))
        #expect(start.previous == start.current)
        #expect(Seeding.start(for: .standard(.automaton)).previous == nil)
    }

    @Test func exactStartsArePlacedForTests() {
        let blinker = Seeding.pattern(gridSize: 8, alive: [(x: 2, y: 4), (x: 3, y: 4), (x: 4, y: 4), (x: 9, y: 9)])
        #expect(AutomatonRule.liveCount(blinker) == 3 && blinker[3, 4, 0] == 1)
        let pulse = Seeding.centredPulse(gridSize: 16, precision: .float32)
        for y in 0..<16 {
            for x in 0..<16 {
                #expect(pulse[x, y, 0] == pulse[15 - x, y, 0] && pulse[x, y, 0] == pulse[x, 15 - y, 0])
            }
        }
        #expect(abs(pulse[7, 7, 0] - Float(exp(-0.5 / 18.0))) < 1e-6)
    }
}

extension Result where Failure == SimulationRefusal {
    /// The refusal reason, or nil on success.
    var refusalReason: SimulationRefusal.Reason? {
        if case .failure(let refusal) = self { return refusal.reason }
        return nil
    }
}
