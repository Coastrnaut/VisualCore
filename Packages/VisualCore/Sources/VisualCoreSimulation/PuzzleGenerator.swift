// PuzzleGenerator — feature 223 (R02-F23) T-R02F23-005 (FR-R02F23-004, 005; clarification Q4; SC-R02F23-004; research
// R5). Turns a seed into a certified level: attempt i draws a candidate from `SeededRandom(seed:
// SeedDerivation.derive(seed, index: i))`, and the first candidate that certifies becomes the level, which records that
// attempt's derived seed so the same maker regenerates it. Every rejected attempt is counted by verdict name.

/// The result of a successful generation: the level, its certificate and what the search cost.
public struct PuzzleGeneration<Rules: PuzzleRules>: Sendable {
    /// The certified level; its `seed` is the derived seed of the successful attempt.
    public let level: PuzzleLevel<Rules>
    /// The certificate of `level` (always valid).
    public let certificate: PuzzleCertificate
    /// The attempts made, the successful one included (1 … the attempt budget).
    public let attempts: Int
    /// The rejected attempts by reason: a verdict name, `"noCandidate"` when the maker returned nil, or `"refused"`
    /// when the candidate could not form a level. The counts sum to `attempts - 1`.
    public let rejections: [String: Int]

    /// A generation result of the given values.
    public init(level: PuzzleLevel<Rules>, certificate: PuzzleCertificate, attempts: Int, rejections: [String: Int]) {
        self.level = level
        self.certificate = certificate
        self.attempts = attempts
        self.rejections = rejections
    }
}

/// Generates certified puzzle levels from seeds.
public enum PuzzleGenerator {
    /// The largest attempt budget.
    public static let maxAttempts = 10_000

    /// Tries up to `attempts` candidates in a fixed order and returns the first one that certifies.
    ///
    /// Attempt i (from 0) gives `make` a `SeededRandom` seeded with `SeedDerivation.derive(seed, index: i)`; the
    /// candidate becomes a level with that derived seed, `rules.rulesID`, `budget` and `uniqueness`, and is certified
    /// with ``PuzzleValidator/certify(_:rules:)``. The maker must draw only from the generator it is given.
    ///
    /// - Throws: `.attempts` unless 1 ≤ attempts ≤ ``maxAttempts``; `.generationFailed(attempts)` when no attempt
    ///   produced a certified level.
    public static func generate<R: PuzzleRules>(
        seed: UInt64, attempts: Int, rules: R, budget: FairnessBudget, uniqueness: PuzzleUniqueness,
        make: (inout SeededRandom) -> (start: R.State, solution: [R.Move])?
    ) throws(PuzzleError) -> PuzzleGeneration<R> {
        guard attempts >= 1, attempts <= maxAttempts else { throw .attempts }
        var rejections: [String: Int] = [:]
        for i in 0..<attempts {
            let derived: UInt64 = SeedDerivation.derive(seed, index: UInt64(i))
            var rng = SeededRandom(seed: derived)
            guard let candidate = make(&rng) else {
                rejections["noCandidate", default: 0] += 1
                continue
            }
            let level: PuzzleLevel<R>
            do {
                level = try PuzzleLevel<R>(rulesID: rules.rulesID, start: candidate.start, solution: candidate.solution,
                                           uniqueness: uniqueness, budget: budget, seed: derived)
            } catch {
                rejections["refused", default: 0] += 1
                continue
            }
            let certificate: PuzzleCertificate = PuzzleValidator.certify(level, rules: rules)
            if certificate.isValid {
                return PuzzleGeneration(level: level, certificate: certificate, attempts: i + 1, rejections: rejections)
            }
            rejections[certificate.verdict.name, default: 0] += 1
        }
        throw .generationFailed(attempts)
    }
}
