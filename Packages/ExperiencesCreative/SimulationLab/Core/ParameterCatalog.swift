// ParameterCatalog — feature 117 (A16-P01) T-A16-102 (FR-A16-111; clarifications Q1–Q3; data-model
// "ParameterDefinition"). The parameter definitions of each simulation family over `VisualCoreParameters`
// `ParameterDefinition`, with the ranges of the data model:
// - cellular automaton: `rule`, the rule preset index 0…2 (0 Life B3/S23, 1 HighLife B36/S23, 2 Seeds B2/S); its
//   time step is one generation (fixed at 1, no definition);
// - reaction-diffusion (Gray-Scott): `feed` F 0…0.1 and `kill` k 0…0.1; time step Δt 0.1…1.5625 (default 1.0);
// - wave field: `speed` c 0.1…2 (default 1) and `damping` γ 0…0.05 (default 0.002); time step Δt 0.05…1 (default
//   0.5), with the Courant number C = c · Δt at or below 1/√2 (checked by `SimulationSpec.validated()`).
// The presets: automata Life, HighLife and Seeds; reaction-diffusion Spots (F 0.035, k 0.065) and Mazes (F 0.029,
// k 0.057); the wave field has one preset, Pulse (the defaults). No other presets are defined by the specification.
import VisualCoreParameters

/// The parameter definitions, time-step definitions and presets of the three simulation families.
public enum ParameterCatalog {
    /// The automaton's rule preset index (0 Life, 1 HighLife, 2 Seeds).
    public static let rule = define("rule", "Rule", "", 0...2, 0)
    /// The Gray-Scott feed rate F.
    public static let feed = define("feed", "Feed", "", 0...0.1, 0.035)
    /// The Gray-Scott kill rate k.
    public static let kill = define("kill", "Kill", "", 0...0.1, 0.065)
    /// The wave speed c, in cells per time unit.
    public static let speed = define("speed", "Wave speed", "cells per time unit", 0.1...2, 1)
    /// The wave damping γ per step.
    public static let damping = define("damping", "Damping", "per step", 0...0.05, 0.002)
    /// The Gray-Scott time step Δt (its stability bound is 1.5625).
    public static let reactionTimeStep = define("timeStep", "Time step", "time units", 0.1...1.5625, 1)
    /// The wave time step Δt (the Courant number c · Δt must also stay at or below 1/√2).
    public static let waveTimeStep = define("timeStep", "Time step", "time units", 0.05...1, 0.5)

    /// The definitions of the values a spec of `kind` holds in `SimulationSpec.parameters`, in display order.
    public static func definitions(for kind: SimulationKind) -> [ParameterDefinition] {
        switch kind {
        case .automaton: [rule]
        case .reactionDiffusion: [feed, kill]
        case .wave: [speed, damping]
        }
    }

    /// The definition of `SimulationSpec.timeStep` for `kind`; nil for the automaton, whose step is one generation.
    public static func timeStepDefinition(for kind: SimulationKind) -> ParameterDefinition? {
        switch kind {
        case .automaton: nil
        case .reactionDiffusion: reactionTimeStep
        case .wave: waveTimeStep
        }
    }

    /// The default time step of `kind`: 1 (one generation), 1.0 (Gray-Scott) or 0.5 (wave).
    public static func defaultTimeStep(for kind: SimulationKind) -> Double {
        timeStepDefinition(for: kind)?.defaultValue ?? 1
    }

    /// The preset names of `kind`, in index order.
    public static func presetNames(for kind: SimulationKind) -> [String] {
        switch kind {
        case .automaton: ["Life", "HighLife", "Seeds"]
        case .reactionDiffusion: ["Spots", "Mazes"]
        case .wave: ["Pulse"]
        }
    }

    /// The parameter values of preset `preset` of `kind` (`preset` clamped into the preset indices).
    public static func presetParameters(for kind: SimulationKind, preset: Int) -> [String: Double] {
        let index = min(max(preset, 0), presetNames(for: kind).count - 1)
        switch kind {
        case .automaton:
            return [rule.name: Double(index)]
        case .reactionDiffusion:
            return index == 0 ? [feed.name: 0.035, kill.name: 0.065] : [feed.name: 0.029, kill.name: 0.057]
        case .wave:
            return [speed.name: speed.defaultValue, damping.name: damping.defaultValue]
        }
    }

    /// A definition from constants that are valid by construction (checked by the tests).
    private static func define(_ name: String, _ title: String, _ unit: String, _ range: ClosedRange<Double>,
                               _ defaultValue: Double) -> ParameterDefinition {
        try! ParameterDefinition(name: name, title: title, unit: unit, range: range, defaultValue: defaultValue)
    }
}
