// BenchmarkCase — feature 173 (A24-P01) T-A24-103 (FR-A24-101, FR-A24-102; clarification Q1; data-model.md
// "Workload", "WorkloadConfig", "RunPlan", "BenchmarkCase"). A benchmark case is a fixed, bounded recipe: a workload
// (textured quads, shader ALU stress or particles), its configuration, a resolution scale and a run plan (warm-up,
// measurement and cool-down lengths in whole seconds), with an id, a version and a fingerprint.
// Choices recorded here: a configuration carries exactly the fields of its workload (quads: layers and texture size;
// alu: iterations; particles: particles); a field of another workload, or a missing one, is refused as
// `wrongWorkloadFields` naming the field. Validation checks, in order: the id (non-empty; lowercase ASCII letters,
// digits and hyphens), the version (at least 1), the workload's fields, their caps, the resolution scale (finite, then
// within its cap) and the plan. The fingerprint is a `StateDigest` of domain `a24.benchmark-case.v1` over the id, the
// version, the workload's raw value, each configuration field in the fixed order layers, textureSize, iterations,
// particles (a presence flag, then the value when present), the resolution scale and the three plan lengths. Pure
// Foundation; no UI, GPU or clock.
import Foundation
import VisualCoreExperience

/// The kind of graphics work a benchmark case drives.
public enum Workload: String, Codable, CaseIterable, Sendable {
    /// Full-screen textured quads drawn in layers over a texture made in code.
    case quads
    /// A fragment shader that runs a fixed number of arithmetic iterations per fragment.
    case alu
    /// A particle system of a fixed size.
    case particles
}

/// The configuration of a workload. Only the fields of the case's workload are present; the resolution scale applies
/// to every workload.
public struct WorkloadConfig: Codable, Equatable, Sendable {
    /// The number of full-screen layers (quads only), within ``CaseLimits/layers``.
    public var layers: Int?
    /// The side of the square texture in texels (quads only), within ``CaseLimits/textureSize`` and a power of two.
    public var textureSize: Int?
    /// The arithmetic iterations per fragment (alu only), within ``CaseLimits/iterations``.
    public var iterations: Int?
    /// The number of particles (particles only), within ``CaseLimits/particles``.
    public var particles: Int?
    /// The fraction of the drawable's resolution rendered, within ``CaseLimits/resolutionScale``.
    public var resolutionScale: Double

    /// A configuration with the given fields (not checked; see ``BenchmarkCase/validate()``).
    public init(layers: Int? = nil, textureSize: Int? = nil, iterations: Int? = nil, particles: Int? = nil,
                resolutionScale: Double = 1.0) {
        self.layers = layers
        self.textureSize = textureSize
        self.iterations = iterations
        self.particles = particles
        self.resolutionScale = resolutionScale
    }
}

/// The phases of a run in whole seconds: warm-up, measurement and cool-down.
public struct RunPlan: Codable, Equatable, Sendable {
    /// The warm-up length in seconds, within ``CaseLimits/warmUpSeconds``; its frames are left out of the statistics.
    public var warmUpSeconds: Int
    /// The measurement length in seconds, within ``CaseLimits/measureSeconds``.
    public var measureSeconds: Int
    /// The cool-down length in seconds, within ``CaseLimits/coolDownSeconds``; its frames are left out.
    public var coolDownSeconds: Int

    /// A plan with the given lengths (not checked; see ``BenchmarkCase/validate()``).
    public init(warmUpSeconds: Int, measureSeconds: Int, coolDownSeconds: Int) {
        self.warmUpSeconds = warmUpSeconds
        self.measureSeconds = measureSeconds
        self.coolDownSeconds = coolDownSeconds
    }

    /// The whole run's length in seconds: warm-up plus measurement plus cool-down.
    public var totalSeconds: Int { warmUpSeconds + measureSeconds + coolDownSeconds }
}

/// The caps of a benchmark case's values.
public enum CaseLimits {
    /// Full-screen layers of the quads workload: 1…64.
    public static let layers: ClosedRange<Int> = 1...64
    /// Texture side of the quads workload: 64…1,024 texels, and a power of two.
    public static let textureSize: ClosedRange<Int> = 64...1_024
    /// Iterations per fragment of the alu workload: 1…1,024.
    public static let iterations: ClosedRange<Int> = 1...1_024
    /// Particles of the particles workload: 1…100,000 (`ParticleSystem.maxCapacity`).
    public static let particles: ClosedRange<Int> = 1...100_000
    /// Resolution scale of every workload: 0.25…1.0.
    public static let resolutionScale: ClosedRange<Double> = 0.25...1.0
    /// Warm-up length: 1…30 s.
    public static let warmUpSeconds: ClosedRange<Int> = 1...30
    /// Measurement length: 1…60 s.
    public static let measureSeconds: ClosedRange<Int> = 1...60
    /// Cool-down length: 0…120 s.
    public static let coolDownSeconds: ClosedRange<Int> = 0...120
}

/// Why a benchmark case was refused.
public enum CaseError: Error, Equatable, Sendable {
    /// The named field is outside its cap (or, for `id`, empty or not lowercase; for `textureSize`, not a power of
    /// two; for `version`, below 1).
    case outOfRange(field: String)
    /// The named field is NaN or infinite.
    case notFinite(field: String)
    /// The named configuration field is present on a workload that has no such field, or missing on one that needs it.
    case wrongWorkloadFields(field: String)
}

/// A benchmark case: a versioned recipe of workload, configuration and run plan.
public struct BenchmarkCase: Codable, Equatable, Sendable {
    /// The stable id: non-empty, lowercase ASCII letters, digits and hyphens.
    public var id: String
    /// The recipe's version, at least 1; any change to the recipe takes a new version.
    public var version: Int
    /// The workload driven.
    public var workload: Workload
    /// The workload's configuration.
    public var config: WorkloadConfig
    /// The run plan.
    public var plan: RunPlan

    /// A case with the given values (not checked; see ``validate()``).
    public init(id: String, version: Int, workload: Workload, config: WorkloadConfig, plan: RunPlan) {
        self.id = id
        self.version = version
        self.workload = workload
        self.config = config
        self.plan = plan
    }

    /// The domain of the case fingerprint.
    public static let fingerprintDomain = "a24.benchmark-case.v1"

    /// The plan of every built-in case: warm-up 3 s, measurement 10 s, cool-down 5 s.
    public static let builtInPlan = RunPlan(warmUpSeconds: 3, measureSeconds: 10, coolDownSeconds: 5)

    /// The built-in textured quads case, version 1: 8 layers over a 256 × 256 texture, resolution 1.0.
    public static let quads = BenchmarkCase(
        id: "quads", version: 1, workload: .quads,
        config: WorkloadConfig(layers: 8, textureSize: 256, resolutionScale: 1.0), plan: builtInPlan)

    /// The built-in shader ALU stress case, version 1: 64 iterations per fragment, resolution 1.0.
    public static let alu = BenchmarkCase(
        id: "alu", version: 1, workload: .alu,
        config: WorkloadConfig(iterations: 64, resolutionScale: 1.0), plan: builtInPlan)

    /// The built-in particles case, version 1: 5,000 particles, resolution 1.0.
    public static let particles = BenchmarkCase(
        id: "particles", version: 1, workload: .particles,
        config: WorkloadConfig(particles: 5_000, resolutionScale: 1.0), plan: builtInPlan)

    /// The three built-in cases, in the order quads, alu, particles.
    public static let builtIn: [BenchmarkCase] = [quads, alu, particles]

    /// Refuses a case outside its caps. Checks, in order: the id and version (``CaseError/outOfRange(field:)``), the
    /// workload's fields (``CaseError/wrongWorkloadFields(field:)``), their caps, the resolution scale
    /// (``CaseError/notFinite(field:)``, then its cap) and the plan lengths.
    public func validate() throws(CaseError) {
        guard id.isEmpty == false, id.unicodeScalars.allSatisfy(Self.isIDScalar) else {
            throw .outOfRange(field: "id")
        }
        guard version >= 1 else { throw .outOfRange(field: "version") }
        try checkFields()
        if let layers = config.layers, CaseLimits.layers.contains(layers) == false {
            throw .outOfRange(field: "layers")
        }
        if let size = config.textureSize, CaseLimits.textureSize.contains(size) == false || size & (size - 1) != 0 {
            throw .outOfRange(field: "textureSize")
        }
        if let iterations = config.iterations, CaseLimits.iterations.contains(iterations) == false {
            throw .outOfRange(field: "iterations")
        }
        if let particles = config.particles, CaseLimits.particles.contains(particles) == false {
            throw .outOfRange(field: "particles")
        }
        guard config.resolutionScale.isFinite else { throw .notFinite(field: "resolutionScale") }
        guard CaseLimits.resolutionScale.contains(config.resolutionScale) else {
            throw .outOfRange(field: "resolutionScale")
        }
        guard CaseLimits.warmUpSeconds.contains(plan.warmUpSeconds) else { throw .outOfRange(field: "warmUpSeconds") }
        guard CaseLimits.measureSeconds.contains(plan.measureSeconds) else {
            throw .outOfRange(field: "measureSeconds")
        }
        guard CaseLimits.coolDownSeconds.contains(plan.coolDownSeconds) else {
            throw .outOfRange(field: "coolDownSeconds")
        }
    }

    /// The fingerprint of the case: a `StateDigest` of domain ``fingerprintDomain`` over the id, the version, the
    /// workload, each configuration field in the order layers, textureSize, iterations, particles (a presence flag,
    /// then the value when present), the resolution scale and the plan's warm-up, measurement and cool-down lengths.
    /// Throws what ``validate()`` throws.
    public func fingerprint() throws(CaseError) -> StateDigest {
        try validate()
        var builder = DigestBuilder(domain: Self.fingerprintDomain)
        builder.add(id)
        builder.add(version)
        builder.add(workload.rawValue)
        let fields: [Int?] = [config.layers, config.textureSize, config.iterations, config.particles]
        for field in fields {
            builder.add(field != nil)
            if let value = field { builder.add(value) }
        }
        do {
            try builder.add(config.resolutionScale)
        } catch {
            throw .notFinite(field: "resolutionScale")
        }
        builder.add(plan.warmUpSeconds)
        builder.add(plan.measureSeconds)
        builder.add(plan.coolDownSeconds)
        return builder.finish()
    }

    /// Refuses a configuration field of another workload, or a missing field of this one, naming the first in the
    /// order layers, textureSize, iterations, particles.
    private func checkFields() throws(CaseError) {
        let needsQuads = workload == .quads
        let checks: [(name: String, present: Bool, needed: Bool)] = [
            ("layers", config.layers != nil, needsQuads),
            ("textureSize", config.textureSize != nil, needsQuads),
            ("iterations", config.iterations != nil, workload == .alu),
            ("particles", config.particles != nil, workload == .particles),
        ]
        for check in checks where check.present != check.needed {
            throw .wrongWorkloadFields(field: check.name)
        }
    }

    /// Whether `scalar` may appear in an id: a lowercase ASCII letter, a digit or a hyphen.
    private static func isIDScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (0x61...0x7A).contains(value) || (0x30...0x39).contains(value) || value == 0x2D
    }
}
