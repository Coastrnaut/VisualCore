// SimulationCore — feature 117 (A16-P01) T-A16-105 (FR-A16-120, FR-A16-130; clarifications Q4, Q5; contracts/core.md).
// The state of Simulation Lab as an experience: a `SimulationModel` (spec, scheduler, field) of the 64 × 64 grid of
// this phase and the preparation seed. Every preparation seed opens the cellular automaton with the Life rule, running
// at speed ×1, at step 0; the seed is the spec's seed, so the seeded start depends on it and `reset()` returns to it.
//
// The core is stepped by the host at 1/60 s (`stepDuration`); each host step runs the iterations the scheduler grants
// (`SimulationModel.advance(hostStep:)`: speed × base rate × 1/60, at most 16), so a running simulation advances with
// the host steps and a paused one does not. The digest therefore depends on the host step count, which the engine
// fixes for a given scenario, so it is deterministic.
//
// Actions (all carried as numbers; the engine refuses a value outside the declared range with `outOfRange`, a
// non-finite value with `nonFinite` and a wrong value count with `wrongValueCount` before the core sees it):
//   sim.family [0…2]   0 cellular automaton, 1 reaction-diffusion, 2 wave field: the family's preset 0 at step 0 with
//                      the same seed, running and speed; a value that is not a whole index is refused with
//                      `a16.invalid-choice`.
//   sim.preset [0…2]   the preset of the current family (automaton Life, HighLife, Seeds; reaction-diffusion Spots,
//                      Mazes; wave Pulse) at step 0 with the same seed, running and speed; an index at or beyond the
//                      family's preset count, or not whole, is refused with `a16.invalid-choice`.
//   sim.run            starts running; refused with `a16.invalid-choice` while running.
//   sim.pause          pauses; refused with `a16.invalid-choice` while paused.
//   sim.step           exactly one iteration while paused (`SimulationModel.singleStep()`); refused with
//                      `a16.invalid-choice` while running.
//   sim.reset          the seeded start at step 0; running and speed are kept (`SimulationModel.reset()`).
//   sim.speed [0…4]    the speed index (×0.25, ×0.5, ×1, ×2, ×4); a value that is not a whole index is refused with
//                      `a16.invalid-choice`.
//   sim.timestep [0.05…2.0]  (feature 119, A16-P03, clarification Q4) the time step Δt of reaction-diffusion or the
//                      wave, keeping the field, the step count, running and speed: Δt above 1.5625 (reaction-diffusion)
//                      or making the Courant number c · Δt exceed 1/√2 (wave) is refused with `a16.unstable`, a Δt
//                      outside the family's own range with `a16.invalid-choice`, and the cellular automaton (one
//                      generation per step) refuses the action with `a16.invalid-choice`. ``timeStepRefusal(_:)`` gives
//                      the refusal with its sentence.
// A spec the core refuses while changing the family or the preset is refused with `a16.unstable` for a stability
// refusal and `a16.invalid-choice` for any other (the standard specs are valid, so neither happens with the shipped
// presets). Called directly (not through the engine), the core refuses an unknown control with `unknownControl` and a
// wrong value count with `wrongValueCount`, as the engine does. A refusal changes nothing.
//
// Snapshot schema 1: the payload is `SimulationState.encoded()` (spec, scheduler and field bits as JSON with sorted
// keys); `restore` reads it through `SimulationState.decode(_:)` and refuses (``SimulationRestoreError``) a damaged,
// newer or out-of-range state and a grid other than 64 (this phase's size). One quality tier (`level-0`).
// The digest is "a16.simulation.v1|" and the SHA-256 of the state's JSON (`SimulationModel.digest`), then the family's
// raw name, the preset index (−1 for parameters that match no preset), the step count, running and the speed index.
//
// The outcome is `simulating-<family>` (`simulating-automaton`, `simulating-reaction-diffusion`, `simulating-wave`) for
// the current family: the completion scenario must expect an outcome, and choosing a family is what a session does.
//
// The canvas description (FR-A16-130) names the family, the rule or preset with its values, the grid size, running or
// paused with the speed, the step count and the field in numbers, so no information depends on colour alone:
// "Simulation Lab: cellular automaton, rule Life (B3/S23); 64 × 64 grid; running at ×1; step 0; 1024 of 4096 cells
// alive."
import Foundation
import SimulationLabCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Simulation Lab's refusals.
public enum SimulationRule {
    /// A family, preset or speed that is not a whole index of its list, a run while running, a pause while paused or a
    /// step while running.
    public static let invalidChoice = "a16.invalid-choice"
    /// A spec beyond its family's stability limit (the Gray-Scott time step or the wave's Courant number).
    public static let unstable = "a16.unstable"
    /// Reaction-diffusion or the wave chosen where floating-point render targets are missing (feature 119, A16-P03;
    /// refused by the presenter, which knows the device; the deterministic core never gives it).
    public static let unsupported = "a16.unsupported"
}

/// Why a stored Simulation Lab state is refused.
public enum SimulationRestoreError: Error, Equatable {
    /// `SimulationState.decode(_:)` refused the payload, for the named reason.
    case refused(SimulationStateRefusal)
    /// The state is valid but its grid is not this phase's 64 × 64.
    case gridSize(Int)
}

/// The state of Simulation Lab. Schema version 1.
public struct SimulationCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a16.simulation-lab"

    /// The action ids in declaration order.
    public static let actionIDs = ["sim.family", "sim.preset", "sim.run", "sim.pause", "sim.step", "sim.reset",
                                   "sim.speed", "sim.timestep"]

    /// The number of values each action carries, by action id.
    static let valueCounts: [String: Int] = ["sim.family": 1, "sim.preset": 1, "sim.run": 0, "sim.pause": 0,
                                             "sim.step": 0, "sim.reset": 0, "sim.speed": 1,
                                             "sim.timestep": 1]

    /// The prefix of the outcome code; the family's outcome name follows.
    public static let outcomePrefix = "simulating-"

    /// The grid size of this phase, 64 cells per side (`SimulationSpec.standardGridSize`).
    public static let gridSize = SimulationSpec.standardGridSize

    /// The families in index order: cellular automaton, reaction-diffusion, wave field.
    public static let families = SimulationKind.allCases

    /// The largest preset index any family declares (2: the automaton's Seeds).
    public static let maxPresetIndex = 2

    /// The preparation seed: the seed of every spec; `reset()` returns to its first state.
    public private(set) var preparationSeed: UInt64
    /// The simulation: spec, scheduler and field.
    public private(set) var model: SimulationModel

    /// The first state with `seed`: the cellular automaton with the Life rule, running at ×1, at step 0.
    public init(seed: UInt64) {
        // The standard spec is valid by construction (SimulationSpecTests), so this never traps.
        self.init(seed: seed, model: try! SimulationModel(spec: .standard(.automaton, preset: 0, seed: seed)))
    }

    /// A core holding `model`, prepared with `seed`.
    init(seed: UInt64, model: SimulationModel) {
        preparationSeed = seed
        self.model = model
    }

    /// The current family.
    public var kind: SimulationKind { model.spec.kind }
    /// The index of the current family in ``families`` (0…2).
    public var familyIndex: Int { Self.families.firstIndex(of: kind) ?? 0 }
    /// The index of the preset whose parameters the spec holds, or nil for parameters that match no preset.
    public var preset: Int? { Self.preset(of: model.spec) }
    /// True while running.
    public var isRunning: Bool { model.isRunning }
    /// The iterations run since the seeded start.
    public var stepCount: Int { model.stepCount }
    /// The speed index, 0…4.
    public var speedIndex: Int { model.scheduler.speedIndex }

    // MARK: Contract

    /// One quality tier (`level-0`): the 64 × 64 CPU field has nothing to scale down.
    public static var qualityTiers: Int { 1 }

    /// One host step is 1/60 s (clarification Q4).
    public static var stepDuration: Double { SimulationScheduler.hostStep }

    /// Schema 1, no migration steps.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: SimulationState.schemaVersion)
    }

    /// The declared range of `sim.timestep`, wider than every family's stable range so the core's refusals with
    /// their sentences are reachable (clarification Q4 of feature 119).
    public static let timeStepRange: ClosedRange<Double> = 0.05...2.0

    /// The automaton's refusal of a time step: it advances one generation per step.
    public static let automatonTimeStepRefusal = SimulationRefusal(
        .outOfRange, "The cellular automaton advances one generation per step: its time step must be 1.")

    /// The eight controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "sim.family", ranges: [0...Double(families.count - 1)]),
         ExperienceControl(id: "sim.preset", ranges: [0...Double(maxPresetIndex)]),
         ExperienceControl(id: "sim.run"),
         ExperienceControl(id: "sim.pause"),
         ExperienceControl(id: "sim.step"),
         ExperienceControl(id: "sim.reset"),
         ExperienceControl(id: "sim.speed", ranges: [0...Double(SimulationScheduler.speeds.count - 1)]),
         ExperienceControl(id: "sim.timestep", ranges: [timeStepRange])]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> SimulationCore {
        try Task.checkCancellation()
        return SimulationCore(seed: seed)
    }

    /// One host step of 1/60 s: the iterations the scheduler grants (none while paused).
    public mutating func update(step: Int) {
        model.advance(hostStep: SimulationScheduler.hostStep)
    }

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard let expected = Self.valueCounts[action.control] else {
            return .rejected(.unknownControl(action.control))
        }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        let refused = ActionResult.rejected(.rule(code: SimulationRule.invalidChoice))
        var next = model
        switch action.control {
        case "sim.family":
            guard let index = Self.choice(v[0], count: Self.families.count) else { return refused }
            let spec = SimulationSpec.standard(Self.families[index], preset: 0, seed: preparationSeed)
            switch Self.remade(next, spec: spec) {
            case .success(let made): next = made
            case .failure(let refusal): return .rejected(.rule(code: Self.ruleCode(for: refusal)))
            }
        case "sim.preset":
            guard let index = Self.choice(v[0], count: ParameterCatalog.presetNames(for: kind).count) else {
                return refused
            }
            let spec = SimulationSpec.standard(kind, preset: index, seed: preparationSeed)
            switch Self.remade(next, spec: spec) {
            case .success(let made): next = made
            case .failure(let refusal): return .rejected(.rule(code: Self.ruleCode(for: refusal)))
            }
        case "sim.run":
            guard !next.isRunning else { return refused }
            next.run()
        case "sim.pause":
            guard next.isRunning else { return refused }
            next.pause()
        case "sim.step":
            guard next.singleStep() else { return refused }
        case "sim.reset":
            next.reset()
        case "sim.timestep":
            if let refusal = timeStepRefusal(v[0]) { return .rejected(.rule(code: Self.ruleCode(for: refusal))) }
            var spec = next.spec
            spec.timeStep = v[0]
            guard let state = SimulationState(spec: spec, scheduler: next.scheduler, field: next.field) else {
                return refused
            }
            next = SimulationModel(state: state)
        default:   // sim.speed
            guard let index = Self.choice(v[0], count: SimulationScheduler.speeds.count), next.setSpeed(index) else {
                return refused
            }
        }
        model = next
        return .accepted
    }

    /// The model of `spec` at step 0 with the running state and speed of `current`; the spec's refusal, or an
    /// `invalidGridSize` refusal for a grid other than 64 (this phase's size).
    static func remade(_ current: SimulationModel, spec: SimulationSpec) -> Result<SimulationModel, SimulationRefusal> {
        if let refusal = spec.refusal() { return .failure(refusal) }
        guard spec.gridSize == gridSize else {
            return .failure(SimulationRefusal(.invalidGridSize, "This version runs the 64 × 64 grid only."))
        }
        guard var made = try? SimulationModel(spec: spec, running: current.isRunning) else {
            return .failure(.damaged)
        }
        made.setSpeed(current.scheduler.speedIndex)
        return .success(made)
    }

    /// Why the current family refuses the time step `value`, with its sentence; nil when it accepts it. The automaton
    /// refuses every value (``automatonTimeStepRefusal``); the other families refuse what `SimulationSpec.refusal()`
    /// refuses for the spec with `value` as its time step (``SimulationRefusal/reactionStep``,
    /// ``SimulationRefusal/courant`` or the range sentence).
    public func timeStepRefusal(_ value: Double) -> SimulationRefusal? {
        guard kind != .automaton else { return Self.automatonTimeStepRefusal }
        var spec = model.spec
        spec.timeStep = value
        return spec.refusal()
    }

    /// The rule code of a refused spec: `a16.unstable` for a stability refusal, `a16.invalid-choice` otherwise.
    static func ruleCode(for refusal: SimulationRefusal) -> String {
        refusal.reason == .unstable ? SimulationRule.unstable : SimulationRule.invalidChoice
    }

    /// The index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// The preset index of `kind` whose parameters equal those of `spec`, or nil when none does.
    static func preset(of spec: SimulationSpec) -> Int? {
        let names = ParameterCatalog.presetNames(for: spec.kind)
        for index in names.indices where ParameterCatalog.presetParameters(for: spec.kind, preset: index)
            == spec.parameters {
            return index
        }
        return nil
    }

    /// `simulating-<family>` of the current family (see the file header).
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: Self.outcomeCode(kind))
    }

    /// The outcome code of `kind`: `simulating-automaton`, `simulating-reaction-diffusion` or `simulating-wave`.
    public static func outcomeCode(_ kind: SimulationKind) -> String {
        outcomePrefix + outcomeName(kind)
    }

    /// The outcome name of `kind`: `automaton`, `reaction-diffusion` or `wave`.
    public static func outcomeName(_ kind: SimulationKind) -> String {
        switch kind {
        case .automaton: "automaton"
        case .reactionDiffusion: "reaction-diffusion"
        case .wave: "wave"
        }
    }

    /// Back to the first state.
    public mutating func reset() {
        self = SimulationCore(seed: preparationSeed)
    }

    /// "a16.simulation.v1|" and the SHA-256 of the state's JSON, then the family, the preset (−1 for none), the step
    /// count, running and the speed index.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add("a16.simulation.v1|" + model.digest)
        builder.add(kind.rawValue)
        builder.add(preset ?? -1)
        builder.add(stepCount)
        builder.add(isRunning)
        builder.add(speedIndex)
    }

    /// The state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        model.state.encoded()
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed; a payload that
    /// `SimulationState.decode(_:)` refuses throws ``SimulationRestoreError/refused(_:)``, a grid other than 64
    /// ``SimulationRestoreError/gridSize(_:)``.
    public static func restore(payload: Data, seed: UInt64) throws -> SimulationCore {
        switch SimulationState.decode(payload) {
        case .success(let state):
            guard state.spec.gridSize == gridSize else { throw SimulationRestoreError.gridSize(state.spec.gridSize) }
            return SimulationCore(seed: seed, model: SimulationModel(state: state))
        case .failure(let reason):
            throw SimulationRestoreError.refused(reason)
        }
    }

    // MARK: Words

    /// The family titles in index order, capitalised for the controls.
    public static let familyTitles = ["Cellular automaton", "Reaction-diffusion", "Wave field"]

    /// The speed factors in words, by speed index: "×0.25", "×0.5", "×1", "×2", "×4".
    public static let speedTitles = ["×0.25", "×0.5", "×1", "×2", "×4"]

    /// The title of the family at `index` ("Wave field"), or "Unknown family" outside 0…2.
    public static func familyTitle(index: Int) -> String {
        familyTitles.indices.contains(index) ? familyTitles[index] : "Unknown family"
    }

    /// The preset titles of `kind` in index order; the automaton's carry the rule ("Life (B3/S23)").
    public static func presetTitles(_ kind: SimulationKind) -> [String] {
        let names = ParameterCatalog.presetNames(for: kind)
        guard kind == .automaton else { return names }
        var titles: [String] = []
        for (index, name) in names.enumerated() {
            let rule = AutomatonRule.presets.indices.contains(index) ? AutomatonRule.presets[index].notation : ""
            titles.append(rule.isEmpty ? name : "\(name) (\(rule))")
        }
        return titles
    }

    /// The speed at `index` in words ("×1"), or "×?" outside 0…4.
    public static func speedTitle(index: Int) -> String {
        speedTitles.indices.contains(index) ? speedTitles[index] : "×?"
    }

    /// `value` as short decimal text: no trailing ".0" ("1", "0.035"), a true minus sign when negative.
    static func decimal(_ value: Double) -> String {
        let text = value == value.rounded() && abs(value) < 1e9 ? String(Int(value)) : String(value)
        return text.hasPrefix("-") ? "\u{2212}" + text.dropFirst() : text
    }

    /// `value` with two decimals ("0.25"), a true minus sign when negative.
    static func twoDecimals(_ value: Float) -> String {
        let text = String(format: "%.2f", Double(value))
        return text.hasPrefix("-") ? "\u{2212}" + text.dropFirst() : text
    }

    /// The rule or preset in words: "rule Life (B3/S23)", "preset Spots (feed 0.035, kill 0.065, time step 1)",
    /// "preset Pulse (wave speed 1, damping 0.002, Courant number 0.5)"; "custom parameters (…)" without a preset.
    public static func presetWords(_ spec: SimulationSpec) -> String {
        let index = preset(of: spec)
        switch spec.kind {
        case .automaton:
            let rule = spec.automatonRule.notation
            guard let index else { return "rule \(rule)" }
            let name = ParameterCatalog.presetNames(for: .automaton)[index]
            return "rule \(name) (\(rule))"
        case .reactionDiffusion:
            let values = "feed \(decimal(spec.value(ParameterCatalog.feed.name))), "
                + "kill \(decimal(spec.value(ParameterCatalog.kill.name))), time step \(decimal(spec.timeStep))"
            guard let index else { return "custom parameters (\(values))" }
            return "preset \(ParameterCatalog.presetNames(for: .reactionDiffusion)[index]) (\(values))"
        case .wave:
            let values = "wave speed \(decimal(spec.value(ParameterCatalog.speed.name))), "
                + "damping \(decimal(spec.value(ParameterCatalog.damping.name))), "
                + "Courant number \(decimal(spec.courantNumber))"
            guard let index else { return "custom parameters (\(values))" }
            return "preset \(ParameterCatalog.presetNames(for: .wave)[index]) (\(values))"
        }
    }

    /// The field in numbers: "1024 of 4096 cells alive" (automaton), "v from 0.00 to 0.25" (reaction-diffusion),
    /// "height from −0.05 to 1.00" (wave). The numbers are the legend's (``SimulationLegendValues``, feature 119), so
    /// the legend and the description share one source.
    public static func fieldWords(_ field: SimulationField, kind: SimulationKind) -> String {
        let legend = SimulationLegendValues.of(field, kind: kind)
        switch kind {
        case .automaton:
            return "\(legend.alive) of \(field.current.width * field.current.height) cells alive"
        case .reactionDiffusion:
            return "v from \(twoDecimals(legend.minimum)) to \(twoDecimals(legend.maximum))"
        case .wave:
            return "height from \(twoDecimals(legend.minimum)) to \(twoDecimals(legend.maximum))"
        }
    }

    /// Running or paused in words: "running at ×1", "paused".
    public var playbackWords: String {
        isRunning ? "running at \(Self.speedTitle(index: speedIndex))" : "paused"
    }

    /// The status line: "Running at ×1, step 120", "Paused, step 0"; reaction-diffusion and the wave add their time
    /// step (feature 119): "Running at ×1, step 120, time step 1".
    public var status: String {
        let words = playbackWords
        let line = (words.first.map { $0.uppercased() + words.dropFirst() } ?? words) + ", step \(stepCount)"
        return kind == .automaton ? line : line + ", time step \(Self.decimal(model.spec.timeStep))"
    }

    /// The canvas description: "Simulation Lab: cellular automaton, rule Life (B3/S23); 64 × 64 grid; running at ×1;
    /// step 0; 1024 of 4096 cells alive."
    public var canvasDescription: String {
        let spec = model.spec
        return "Simulation Lab: \(kind.title), \(Self.presetWords(spec)); \(spec.gridSize) × \(spec.gridSize) grid; "
            + "\(playbackWords); step \(stepCount); \(Self.fieldWords(model.field, kind: kind))."
    }
}
