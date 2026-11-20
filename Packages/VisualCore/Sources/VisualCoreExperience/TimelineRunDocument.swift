// TimelineRunDocument.swift — a stored run of a reversible timeline: schema-1 JSON with a migration from schema 0,
// reopened by replaying to the stored step and verifying the replay hash
// (feature 214 R02-F14 T-R02F14-004; FR-R02F14-006; SC-R02F14-005; clarification Q5; research R5).
import Foundation
import VisualCorePersistence
import VisualCoreSimulation

/// A saved `ReversibleTimeline`: its start state, event log, current step and replay hash, plus the step duration,
/// snapshot interval and ring capacity so that reopening rebuilds the same timeline.
///
/// Stored as JSON with sorted keys:
/// `{"capacity":c,"dt":d,"hash":"<64 hex>","interval":i,"log":[{"command":…,"step":s},…],"schema":1,"start":…,"step":n}`.
/// Opening (`decode(_:apply:)`) migrates older schemas, replays from `start` to `step` and refuses the run when the
/// replay hash differs from the stored one, so a damaged or tampered run is detected rather than trusted.
public struct TimelineRunDocument<State: Codable & FixedStepSimulation & Sendable,
                                  Command: Codable & Sendable & Equatable>: Sendable {
    /// The schema this build writes (1).
    public static var schema: Int { 1 }

    /// Upgrades stored payloads to `schema`. Step 0 → 1 turns a schema-0 `log` of `[step, command]` two-element
    /// arrays into the schema-1 form, an array of `{"step": step, "command": command}` objects.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 1, steps: [0: { payload in
            guard let pairs = payload["log"] as? [Any] else { throw MigrationRefusal.log }
            var entries: [[String: Any]] = []
            entries.reserveCapacity(pairs.count)
            for item in pairs {
                guard let pair = item as? [Any], pair.count == 2 else { throw MigrationRefusal.log }
                entries.append(["step": pair[0], "command": pair[1]])
            }
            var upgraded = payload
            upgraded["log"] = entries
            upgraded["schema"] = 1
            return upgraded
        }])
    }

    /// The state at step 0.
    public let start: State
    /// The commands of the run.
    public let log: EventLog<Command>
    /// Steps completed when the run was saved.
    public let step: Int
    /// The replay hash after `step` steps.
    public let hash: ReplayHash
    /// The fixed step duration in seconds of the saved timeline (rebuilt on reopening).
    public let dt: Double
    /// The snapshot interval of the saved timeline (rebuilt on reopening).
    public let interval: Int
    /// The snapshot ring capacity of the saved timeline (rebuilt on reopening).
    public let capacity: Int

    /// Captures `timeline` as it stands: start, log, step, hash, step duration, snapshot interval and ring capacity.
    public init(timeline: ReversibleTimeline<State, Command>) {
        start = timeline.start; log = timeline.log; step = timeline.step; hash = timeline.hash
        dt = timeline.dt; interval = timeline.ring.interval; capacity = timeline.ring.capacity
    }

    /// The run as schema-1 JSON with sorted keys; identical documents give identical bytes.
    public func encoded() throws -> Data {
        let stored = Stored(schema: Self.schema, start: start, log: log.entries, step: step, hash: hash,
                            dt: dt, interval: interval, capacity: capacity)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(stored)
    }

    /// Reopens a stored run: parses it, migrates an older schema, rebuilds the timeline with `apply`, seeks to the
    /// stored step and compares the replay hash with the stored one.
    ///
    /// Refuses unreadable JSON, a missing or non-integer `schema` or an undecodable part (`.malformed`), a schema
    /// above `schema` (`.newerSchema`), a log above `EventLog.maxEntries` (`.logLimit`), a step outside the limits
    /// (`.negativeStep`, `.stepLimit`), an invalid interval or capacity (`.interval`, `.ringSize`) and a replay whose
    /// hash differs from the stored one (`.hashMismatch`).
    public static func decode(_ data: Data, apply: @escaping @Sendable (inout State, Command) -> Void)
        throws(TimelineError) -> ReversibleTimeline<State, Command> {
        let object: Any
        do { object = try JSONSerialization.jsonObject(with: data) } catch { throw .malformed("not JSON") }
        guard let payload = object as? [String: Any] else { throw .malformed("not a JSON object") }
        guard let number = payload["schema"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              let version = Int(exactly: number.doubleValue) else { throw .malformed("schema missing or not an integer") }
        guard version <= schema else { throw .newerSchema(version) }
        guard version >= 0 else { throw .malformed("negative schema") }
        if let entries = payload["log"] as? [Any], entries.count > EventLog<Command>.maxEntries { throw .logLimit }

        var body = data
        if version < schema {
            let upgraded: [String: Any]
            do { upgraded = try migrations.migrate(payload, from: version) } catch { throw .malformed("migration failed") }
            do { body = try JSONSerialization.data(withJSONObject: upgraded) } catch { throw .malformed("migration output") }
        }

        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: body) } catch { throw .malformed("undecodable run") }
        guard stored.log.count <= EventLog<Command>.maxEntries else { throw .logLimit }

        var log = EventLog<Command>()
        for entry in stored.log.enumerated().sorted(by: {
            $0.element.step != $1.element.step ? $0.element.step < $1.element.step : $0.offset < $1.offset
        }).map(\.element) {
            try log.insert(entry.command, at: entry.step)
        }
        var timeline = try ReversibleTimeline(start: stored.start, dt: stored.dt, interval: stored.interval,
                                              capacity: stored.capacity, log: log, apply: apply)
        try timeline.seek(to: stored.step)
        guard timeline.hash == stored.hash else { throw .hashMismatch }
        return timeline
    }

    /// The schema-1 JSON shape.
    private struct Stored: Codable {
        let schema: Int
        let start: State
        let log: [EventLog<Command>.Entry]
        let step: Int
        let hash: ReplayHash
        let dt: Double
        let interval: Int
        let capacity: Int
    }
}

/// Why the schema-0 → 1 migration could not convert a payload (reported to callers as `TimelineError.malformed`).
private enum MigrationRefusal: Error { case log }
