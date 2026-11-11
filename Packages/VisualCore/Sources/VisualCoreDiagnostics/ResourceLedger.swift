// ResourceLedger.swift — GPU resource accounting: budgets, live counts, peak, stale use, leaks,
// shader failures and deduplicated warnings (feature 004 T-F309; FR-F309–FR-F311, FR-F316).
// Pure value type: the iOS ResourceRegistry records every GL allocation here.

public enum ResourceKind: String, CaseIterable, Sendable, Codable {
    case texture, buffer, framebuffer, renderbuffer, program, shader, vertexArray
}

public struct ResourceBudget: Sendable, Equatable {
    public static let defaultTotal = 256 << 20
    public var total: Int
    public var perKind: [ResourceKind: Int]
    public init(total: Int = ResourceBudget.defaultTotal, perKind: [ResourceKind: Int] = [:]) {
        self.total = total
        self.perKind = perKind
    }
}

public enum ResourceBudgetError: Error, Equatable, Sendable {
    case overBudget(ResourceKind, requested: Int, available: Int)
}

public struct ResourceLedger: Sendable {
    public struct Snapshot: Sendable, Equatable, Codable {
        public var liveCount: [ResourceKind: Int]
        public var liveBytes: [ResourceKind: Int]
        public var totalBytes: Int
        public var peakBytes: Int
        public var staleRejected: Int
        public var leaked: Int
        public var shaderFailures: Int
        public var warnings: [String]
        /// Live objects of all kinds.
        public var liveTotal: Int { liveCount.values.reduce(0, +) }
    }

    public let budget: ResourceBudget
    private var count: [ResourceKind: Int] = [:]
    private var bytes: [ResourceKind: Int] = [:]
    private var peak = 0
    private var stale = 0
    private var leaks = 0
    private var shaderFailureCount = 0
    private var warningList: [String] = []
    private var warningSet: Set<String> = []

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

    public mutating func noteStale() { stale += 1 }
    public mutating func noteShaderFailure() { shaderFailureCount += 1 }

    /// Records a warning once; returns true when it is new.
    @discardableResult
    public mutating func warn(_ message: String) -> Bool {
        guard warningSet.insert(message).inserted else { return false }
        warningList.append(message)
        return true
    }

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
