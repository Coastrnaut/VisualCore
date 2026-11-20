// EventLog.swift — commands by step in a stable order, editable by (step, index)
// (feature 214 R02-F14 T-R02F14-002; FR-R02F14-001, FR-R02F14-007; clarification Q2).

/// Commands held by step (0 … 10,000,000) in a stable order: by step, then by insertion order within a step. At most
/// 1,048,576 commands. A command at step s applies just before the simulation advances from s to s + 1.
public struct EventLog<Command: Sendable & Equatable>: Sendable, Equatable {
    /// One command and the step before whose advance it applies.
    public struct Entry: Sendable, Equatable {
        /// Steps completed when the command applies.
        public let step: Int
        /// The command.
        public let command: Command
        /// Creates an entry applying `command` at `step`.
        public init(step: Int, command: Command) { self.step = step; self.command = command }
    }

    /// The highest step a command may be placed at (10,000,000).
    public static var maxStep: Int { 10_000_000 }
    /// The most commands a log may hold (1,048,576).
    public static var maxEntries: Int { 1_048_576 }

    /// Creates an empty log.
    public init() {}

    /// The entries, sorted by step and stable within a step.
    public private(set) var entries: [Entry] = []

    /// The number of commands.
    public var count: Int { entries.count }

    /// The distinct steps holding at least one command, ascending.
    public var steps: [Int] {
        var result: [Int] = []
        for entry in entries where result.last != entry.step { result.append(entry.step) }
        return result
    }

    /// Appends `command` after the commands already at `step`; refuses a step outside 0 … `maxStep` or a full log.
    public mutating func insert(_ command: Command, at step: Int) throws(TimelineError) {
        try Self.check(step)
        guard entries.count < Self.maxEntries else { throw .logLimit }
        entries.insert(Entry(step: step, command: command), at: upperBound(step))
    }

    /// Removes and returns the command at position `index` within `step`; refuses a missing one.
    @discardableResult
    public mutating func remove(at step: Int, index: Int) throws(TimelineError) -> Command {
        let position = try locate(step: step, index: index)
        return entries.remove(at: position).command
    }

    /// Replaces the command at position `index` within `step`; refuses a missing one.
    public mutating func replace(at step: Int, index: Int, with command: Command) throws(TimelineError) {
        let position = try locate(step: step, index: index)
        entries[position] = Entry(step: step, command: command)
    }

    /// The commands at `step`, in insertion order.
    public func commands(at step: Int) -> [Command] {
        entries[lowerBound(step)..<upperBound(step)].map(\.command)
    }

    /// The index range of `entries` at `step` (internal: the timeline walks it without copying).
    internal func range(at step: Int) -> Range<Int> { lowerBound(step)..<upperBound(step) }

    private static func check(_ step: Int) throws(TimelineError) {
        guard step >= 0 else { throw .negativeStep }
        guard step <= maxStep else { throw .stepLimit(step) }
    }

    private func locate(step: Int, index: Int) throws(TimelineError) -> Int {
        let range = lowerBound(step)..<upperBound(step)
        guard index >= 0, index < range.count else { throw .noSuchCommand(step: step, index: index) }
        return range.lowerBound + index
    }

    /// The first position whose step is ≥ `step`.
    private func lowerBound(_ step: Int) -> Int {
        var low = 0, high = entries.count
        while low < high {
            let mid = (low + high) / 2
            if entries[mid].step < step { low = mid + 1 } else { high = mid }
        }
        return low
    }

    /// The first position whose step is > `step`.
    private func upperBound(_ step: Int) -> Int {
        var low = 0, high = entries.count
        while low < high {
            let mid = (low + high) / 2
            if entries[mid].step <= step { low = mid + 1 } else { high = mid }
        }
        return low
    }
}

extension EventLog.Entry: Codable where Command: Codable {}

/// Encoded as an array of `{"step", "command"}` objects; decoding re-applies the step and size limits and keeps the
/// stored order within a step.
extension EventLog: Codable where Command: Codable {
    /// Decodes an array of entries, refusing (as `DecodingError.dataCorrupted`) a step or size outside the limits.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stored = try container.decode([Entry].self)
        var log = EventLog()
        for entry in stored.enumerated().sorted(by: {
            $0.element.step != $1.element.step ? $0.element.step < $1.element.step : $0.offset < $1.offset
        }).map(\.element) {
            do { try log.insert(entry.command, at: entry.step) } catch {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                        debugDescription: "event log refused: \(error.reasonCode)"))
            }
        }
        self = log
    }

    /// Encodes the entries as an array in log order.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(entries)
    }
}
