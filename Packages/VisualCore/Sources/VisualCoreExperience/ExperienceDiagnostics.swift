// ExperienceDiagnostics — feature 188 T-U02-016 (the GPU counts the engine's deactivation takes) and T-U02-028 (the
// diagnostics value; FR-U02-060, FR-U02-061; data-model section 5).
import Foundation

/// The GPU objects of a render host at one moment, as plain numbers, so that pure code can state and check them.
public struct GPUResourceCounts: Sendable, Equatable, Codable {
    /// Live GPU objects of all kinds.
    public let objects: Int
    /// Bytes held by the live objects.
    public let bytes: Int
    /// Objects that were still live when their context ended.
    public let leaked: Int

    /// Creates the counts.
    public init(objects: Int, bytes: Int, leaked: Int) {
        self.objects = objects
        self.bytes = bytes
        self.leaked = leaked
    }
}

/// The readable state of an experience at one moment: what a tester, the verification runner and a failure report
/// read. An item that does not exist yet is nil and is left out of the encoded form; nothing is made up.
public struct ExperienceDiagnostics: Sendable, Equatable, Codable {
    /// The experience.
    public let experience: ExperienceID
    /// The lifecycle state.
    public let state: ExperienceLifecycleState
    /// The seed of the current or last preparation or restored snapshot; nil before the first preparation.
    public let seed: UInt64?
    /// Steps run since preparation, reset or the restored snapshot's capture.
    public let stepIndex: Int
    /// The quality tier (0 is the best).
    public let qualityTier: Int
    /// The GPU objects of the render host; nil without one.
    public let gpu: GPUResourceCounts?
    /// The last error; it stays until a preparation succeeds.
    public let lastError: ExperienceFailure?
    /// The digest of the domain state; nil without a prepared core.
    public let digest: StateDigest?
    /// Lifecycle transitions that were refused.
    public let rejectedTransitions: Int
    /// Operations that were refused because of the lifecycle state.
    public let rejectedOperations: Int
    /// Actions carried out.
    public let acceptedActions: Int
    /// Actions rejected.
    public let rejectedActions: Int
    /// Seconds of simulated time lost to the per-frame step limit.
    public let droppedTime: Double
    /// Frames whose time was negative or not finite.
    public let invalidFrames: Int
    /// The outcome the core reports (feature 195, UA-F09); nil without a prepared core or without an outcome. Left
    /// out of the encoded form when nil, and read as nil from an encoded value that has none.
    public let outcome: ExperienceOutcome?

    /// Creates a diagnostics value. `outcome` comes last and defaults to nil, so older call sites stay valid.
    public init(experience: ExperienceID, state: ExperienceLifecycleState, seed: UInt64?, stepIndex: Int, qualityTier: Int,
                gpu: GPUResourceCounts?, lastError: ExperienceFailure?, digest: StateDigest?, rejectedTransitions: Int,
                rejectedOperations: Int, acceptedActions: Int, rejectedActions: Int, droppedTime: Double, invalidFrames: Int,
                outcome: ExperienceOutcome? = nil) {
        self.experience = experience
        self.state = state
        self.seed = seed
        self.stepIndex = stepIndex
        self.qualityTier = qualityTier
        self.gpu = gpu
        self.lastError = lastError
        self.digest = digest
        self.rejectedTransitions = rejectedTransitions
        self.rejectedOperations = rejectedOperations
        self.acceptedActions = acceptedActions
        self.rejectedActions = rejectedActions
        self.droppedTime = droppedTime
        self.invalidFrames = invalidFrames
        self.outcome = outcome
    }

    private enum CodingKeys: String, CodingKey {
        case experience, state, seed, stepIndex, qualityTier, gpu, lastError, digest, rejectedTransitions, rejectedOperations
        case acceptedActions, rejectedActions, droppedTime, invalidFrames, outcome
    }

    /// Decodes a diagnostics value; the seed is read from decimal text and a missing outcome is nil.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        experience = try c.decode(ExperienceID.self, forKey: .experience)
        state = try c.decode(ExperienceLifecycleState.self, forKey: .state)
        if let text = try c.decodeIfPresent(String.self, forKey: .seed) {
            guard let value = UInt64(text) else {
                throw DecodingError.dataCorruptedError(forKey: .seed, in: c, debugDescription: "the seed is not a 64-bit number")
            }
            seed = value
        } else {
            seed = nil
        }
        stepIndex = try c.decode(Int.self, forKey: .stepIndex)
        qualityTier = try c.decode(Int.self, forKey: .qualityTier)
        gpu = try c.decodeIfPresent(GPUResourceCounts.self, forKey: .gpu)
        lastError = try c.decodeIfPresent(ExperienceFailure.self, forKey: .lastError)
        digest = try c.decodeIfPresent(StateDigest.self, forKey: .digest)
        rejectedTransitions = try c.decode(Int.self, forKey: .rejectedTransitions)
        rejectedOperations = try c.decode(Int.self, forKey: .rejectedOperations)
        acceptedActions = try c.decode(Int.self, forKey: .acceptedActions)
        rejectedActions = try c.decode(Int.self, forKey: .rejectedActions)
        droppedTime = try c.decode(Double.self, forKey: .droppedTime)
        invalidFrames = try c.decode(Int.self, forKey: .invalidFrames)
        outcome = try c.decodeIfPresent(ExperienceOutcome.self, forKey: .outcome)
    }

    /// Encodes the value; the seed is written as decimal text and absent items are left out.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(experience, forKey: .experience)
        try c.encode(state, forKey: .state)
        try c.encodeIfPresent(seed.map { String($0) }, forKey: .seed)
        try c.encode(stepIndex, forKey: .stepIndex)
        try c.encode(qualityTier, forKey: .qualityTier)
        try c.encodeIfPresent(gpu, forKey: .gpu)
        try c.encodeIfPresent(lastError, forKey: .lastError)
        try c.encodeIfPresent(digest, forKey: .digest)
        try c.encode(rejectedTransitions, forKey: .rejectedTransitions)
        try c.encode(rejectedOperations, forKey: .rejectedOperations)
        try c.encode(acceptedActions, forKey: .acceptedActions)
        try c.encode(rejectedActions, forKey: .rejectedActions)
        try c.encode(droppedTime, forKey: .droppedTime)
        try c.encode(invalidFrames, forKey: .invalidFrames)
        try c.encodeIfPresent(outcome, forKey: .outcome)
    }

    /// The value as JSON with keys in sorted order, for evidence files.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
