// ResourceLedger.swift — GPU resource accounting: budgets, live counts, peak, stale use, leaks,
// shader failures and deduplicated warnings (feature 004 T-F309; FR-F309–FR-F311, FR-F316).
// Pure value type: the iOS ResourceRegistry records every GL allocation here.

/// GL object categories tracked by the ledger.
public enum ResourceKind: String, CaseIterable, Sendable, Codable {
    case texture, buffer, framebuffer, renderbuffer, program, shader, vertexArray
}

/// Byte limits for live GPU resources: an overall total and optional per-kind caps.
public struct ResourceBudget: Sendable, Equatable {
    /// Default overall budget: 256 MiB.
    public static let defaultTotal = 256 << 20
    /// Maximum live bytes across all kinds.
    public var total: Int
    /// Optional maximum live bytes per kind; kinds without an entry are limited only by `total`.
    public var perKind: [ResourceKind: Int]
    /// Defaults to 256 MiB total with no per-kind caps.
    public init(total: Int = ResourceBudget.defaultTotal, perKind: [ResourceKind: Int] = [:]) {
        self.total = total
        self.perKind = perKind
    }
}

/// Thrown by `ResourceLedger.allocate` when an allocation would exceed a budget.
public enum ResourceBudgetError: Error, Equatable, Sendable {
    case overBudget(ResourceKind, requested: Int, available: Int)
}

/// Accounts for live GPU objects and bytes against a budget, plus stale uses, leaks, shader failures and warnings.
public struct ResourceLedger: Sendable {
    /// Codable point-in-time copy of the ledger for diagnostics export.
    public struct Snapshot: Sendable, Equatable, Codable {
        /// Live objects per kind (every kind present, zero when none).
        public var liveCount: [ResourceKind: Int]
        /// Live bytes per kind (every kind present).
        public var liveBytes: [ResourceKind: Int]
        /// Live bytes across all kinds.
        public var totalBytes: Int
        /// Highest `totalBytes` seen since creation (not reset by `abandonAll`).
        public var peakBytes: Int
        /// Uses of a resource from an older context generation that were rejected.
        public var staleRejected: Int
        /// Objects still live when their context was destroyed or recreated (`abandonAll`).
        public var leaked: Int
        /// Shader compile or program link failures.
        public var shaderFailures: Int
        /// Distinct warning messages in first-seen order.
        public var warnings: [String]
        /// Live objects of all kinds.
        public var liveTotal: Int { liveCount.values.reduce(0, +) }
    }

    /// Limits enforced by `allocate`.
    public let budget: ResourceBudget
    private var count: [ResourceKind: Int] = [:]
    private var bytes: [ResourceKind: Int] = [:]
    private var peak = 0
    private var stale = 0
    private var leaks = 0
    private var shaderFailureCount = 0
    private var warningList: [String] = []
    private var warningSet: Set<String> = []

    /// Creates an empty ledger (default budget: 256 MiB, no per-kind caps).
    public init(budget: ResourceBudget = ResourceBudget()) { self.budget = budget }

    private var totalBytes: Int { bytes.values.reduce(0, +) }

    /// Records an allocation, or throws without changing anything when it would exceed a budget.
    public mutating func allocate(_ kind: ResourceKind, bytes amount: Int) throws(ResourceBudgetError) {
        let amount = max(0, amount)
        var available = budget.total - totalBytes
        if let kindLimit = budget.perKind[kind] { available = min(available, kindLimit - bytes[kind, default: 0]) }
        guard amount <= available else { throw .overBudget(kind, requested: amount, available: max(0, available)) }
        count[kind, default: 0] += 1
        bytes[kind, default: 0] += amount
        peak = max(peak, totalBytes)
    }

    /// Records a release of one `kind` object of `amount` bytes; ignored when none of that kind is live.
    public mutating func release(_ kind: ResourceKind, bytes amount: Int) {
        guard count[kind, default: 0] > 0 else { return }
        count[kind, default: 0] -= 1
        bytes[kind] = max(0, bytes[kind, default: 0] - max(0, amount))
    }

    /// Context recreated or destroyed: every live object is counted as leaked and forgotten
    /// (its GL objects died with the context). Returns how many were abandoned.
    @discardableResult
    public mutating func abandonAll() -> Int {
        let live = count.values.reduce(0, +)
        leaks += live
        count.removeAll()
        bytes.removeAll()
        return live
    }

    /// Counts a rejected use of a stale (previous-generation) resource handle.
    public mutating func noteStale() { stale += 1 }
    /// Counts a shader compile or program link failure.
    public mutating func noteShaderFailure() { shaderFailureCount += 1 }

    /// Records a warning once; returns true when it is new.
    @discardableResult
    public mutating func warn(_ message: String) -> Bool {
        guard warningSet.insert(message).inserted else { return false }
        warningList.append(message)
        return true
    }

    /// Current counters as a `Snapshot`.
    public var snapshot: Snapshot {
        var live: [ResourceKind: Int] = [:]
        var liveB: [ResourceKind: Int] = [:]
        for k in ResourceKind.allCases {
            live[k] = count[k, default: 0]
            liveB[k] = bytes[k, default: 0]
        }
        return Snapshot(liveCount: live, liveBytes: liveB, totalBytes: totalBytes, peakBytes: peak, staleRejected: stale,
                        leaked: leaks, shaderFailures: shaderFailureCount, warnings: warningList)
    }
}
