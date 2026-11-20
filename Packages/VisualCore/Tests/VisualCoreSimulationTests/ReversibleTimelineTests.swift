// ReversibleTimelineTests — feature 214 R02-F14 T-R02F14-003 (FR-R02F14-002…005, FR-R02F14-007;
// SC-R02F14-001…004; clarifications Q2–Q4; research R2–R4).
import Testing
@testable import VisualCoreSimulation

/// A small seeded particle-like state: position, velocity and a SplitMix-style integer state.
private struct Drift: FixedStepSimulation, Sendable, Equatable {
    var x = 0.0, v = 0.25, w = 1.0
    var rng: UInt64 = 2_014

    mutating func step(_ dt: Double) {
        rng &+= 0x9e37_79b9_7f4a_7c15
        var z = rng
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        z ^= z >> 31
        let noise = Double(z >> 11) * 0x1p-53 - 0.5
        v += noise * dt - 0.1 * x * dt
        x += v * dt
        w = w * 0.999 + abs(v) * dt
    }

    func checksum() -> UInt64 { fnv([x.bitPattern, v.bitPattern, w.bitPattern, rng]) }
}

private enum Nudge: Sendable, Equatable { case push(Double), spin(UInt64) }

private let applyNudge: @Sendable (inout Drift, Nudge) -> Void = { state, nudge in
    switch nudge {
    case .push(let dv): state.v += dv
    case .spin(let s): state.rng ^= s
    }
}

private func fnv(_ words: [UInt64]) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for word in words { for i in 0..<8 { h = (h ^ UInt64(UInt8(truncatingIfNeeded: word >> (UInt64(i) * 8)))) &* 0x100_0000_01b3 } }
    return h
}

private let dt = 1.0 / 120

/// 100 seeded commands at steps 0..<1,000 (seed 2,014), as (step, command) in insertion order.
private func seededCommands() -> [(Int, Nudge)] {
    var random = SeededRandom(seed: 2_014)
    return (0..<100).map { i in
        let step = Int(random.next() % 1_000)
        let r = random.next()
        return (step, i % 5 == 4 ? .spin(r) : .push(Double(r % 2_001) / 1_000 - 1))
    }
}

/// An independent straight run: state, checksum and (when `hashing`) hash after each step 0…`steps`; `from` resumes a
/// run whose first `from.step` steps are unchanged.
private struct Trace { var states: [Drift] = [], checksums: [UInt64] = [], hashes: [ReplayHash] = [] }

private func freshRun(_ commands: [(Int, Nudge)], steps: Int = 1_000, hashing: Bool = true,
                      from: (step: Int, state: Drift, hash: ReplayHash)? = nil) -> Trace {
    var byStep: [Int: [Nudge]] = [:]
    for (step, command) in commands { byStep[step, default: []].append(command) }
    var state = from?.state ?? Drift()
    var hash = from?.hash ?? ReplayHash.start(checksum: state.checksum())
    var trace = Trace(states: [state], checksums: [state.checksum()], hashes: [hash])
    for n in (from?.step ?? 0)..<steps {
        for command in byStep[n] ?? [] { applyNudge(&state, command) }
        state.step(dt)
        if hashing { hash = hash.next(step: n + 1, checksum: state.checksum()); trace.hashes.append(hash) }
        trace.states.append(state); trace.checksums.append(state.checksum())
    }
    return trace
}

private func timeline(_ commands: [(Int, Nudge)], interval: Int = 64, capacity: Int = 32) throws -> ReversibleTimeline<Drift, Nudge> {
    var log = EventLog<Nudge>()
    for (step, command) in commands { try log.insert(command, at: step) }
    return try ReversibleTimeline(start: Drift(), dt: dt, interval: interval, capacity: capacity, log: log, apply: applyNudge)
}

@Test func timelineSeeksMatchAFreshRun() throws {
    let commands = seededCommands()
    let fresh = freshRun(commands)
    var tl = try timeline(commands)
    try tl.advance(steps: 1_000)
    #expect(tl.state.checksum() == fresh.checksums[1_000] && tl.hash == fresh.hashes[1_000])
    #expect(tl.ring.snapshots.map(\.step) == (1...15).map { $0 * 64 })
    var random = SeededRandom(seed: 2_014_200)
    for _ in 0..<200 {
        let k = Int(random.next() % 1_001)
        try tl.seek(to: k)
        #expect(tl.step == k && tl.state.checksum() == fresh.checksums[k] && tl.hash == fresh.hashes[k])
    }
    try tl.seek(to: 1_000)
    #expect(tl.state.checksum() == fresh.checksums[1_000] && tl.hash == fresh.hashes[1_000])
    #expect(try tl.hash(at: 500) == fresh.hashes[500] && tl.step == 1_000)
}

@Test func timelineEditsEqualAFreshRunOfTheEditedLog() throws {
    var commands = seededCommands()
    var tl = try timeline(commands)
    try tl.advance(steps: 1_000)
    var random = SeededRandom(seed: 2_014_050)
    var before = freshRun(commands, hashing: false).checksums
    for e in 0..<50 {
        var s = Int(random.next() % 1_000)
        switch e % 3 {
        case 0:
            let command = Nudge.push(Double(random.next() % 101) / 100)
            try tl.insert(command, at: s); commands.append((s, command))
        case 1:
            s = commands[Int(random.next() % UInt64(commands.count))].0
            let at = commands.indices.first { commands[$0].0 == s }!
            try tl.remove(at: s, index: 0); commands.remove(at: at)
        default:
            s = commands[Int(random.next() % UInt64(commands.count))].0
            let at = commands.indices.first { commands[$0].0 == s }!
            let command = Nudge.spin(random.next())
            try tl.replace(at: s, index: 0, with: command); commands[at] = (s, command)
        }
        let edited = freshRun(commands, hashing: false).checksums
        #expect(tl.step == 1_000 && tl.state.checksum() == edited[1_000])
        #expect(Array(edited[0...s]) == Array(before[0...s]))
        let recomputed = tl.hash
        try tl.seek(to: s)
        #expect(tl.state.checksum() == before[s])
        for k in (s + 1)...1_000 {
            try tl.advance()
            #expect(tl.state.checksum() == edited[k])
        }
        #expect(tl.hash == recomputed)
        before = edited
    }
    #expect(tl.hash == freshRun(commands).hashes[1_000])
}

@Test func timelineEditLeavesEarlierStepsUnchanged() throws {
    let commands = seededCommands()
    let original = freshRun(commands)
    var tl = try timeline(commands)
    try tl.advance(steps: 1_000)
    var random = SeededRandom(seed: 2_014_051)
    for _ in 0..<10 {
        let s = Int(random.next() % 1_000)
        try tl.insert(.push(0.5), at: s)
        for k in [0, s / 2, s] {
            try tl.seek(to: k)
            #expect(tl.state.checksum() == original.checksums[k] && tl.hash == original.hashes[k])
        }
        try tl.seek(to: 1_000)
        #expect(tl.hash != original.hashes[1_000])
        try tl.remove(at: s, index: tl.log.commands(at: s).count - 1)
        #expect(tl.hash == original.hashes[1_000])
    }
}

@Test func timelineEditBeyondTheCurrentStepOnlyChangesTheLog() throws {
    var tl = try timeline(seededCommands())
    try tl.advance(steps: 100)
    let hash = tl.hash
    try tl.insert(.push(1), at: 100)
    try tl.insert(.push(1), at: 500)
    #expect(tl.hash == hash && tl.step == 100 && tl.log.count == 102)
    #expect(throws: TimelineError.noSuchCommand(step: 7, index: 9)) { try tl.remove(at: 7, index: 9) }
}

@Test func timelineHashesAreIdenticalAndSensitiveToEachCommand() throws {
    let commands = seededCommands()
    var a = try timeline(commands), b = try timeline(commands)
    try a.advance(steps: 1_000); try b.advance(steps: 1_000)
    let straight = freshRun(commands).hashes[1_000]
    #expect(a.hash == b.hash && a.hash == straight)
    try a.seek(to: 0); try a.seek(to: 1_000)
    #expect(a.hash == straight)
    let trace = freshRun(commands)
    var changed = 0
    for i in 0..<100 {
        var variant = commands
        switch variant[i].1 {
        case .push(let dv): variant[i].1 = .push(dv + 0.125)
        case .spin(let s): variant[i].1 = .spin(s ^ 1)
        }
        let s = variant[i].0
        let resumed = freshRun(variant, from: (s, trace.states[s], trace.hashes[s]))
        if resumed.hashes.last != straight { changed += 1 }
    }
    #expect(changed == 100)
}

@Test func timelineSmallRingStaysExactAndBoundsReplay() throws {
    let commands = seededCommands()
    let fresh = freshRun(commands)
    var tl = try timeline(commands, interval: 64, capacity: 4)
    try tl.advance(steps: 1_000)
    #expect(tl.ring.snapshots.map(\.step) == [768, 832, 896, 960])
    var random = SeededRandom(seed: 2_014_004)
    var maxFromSnapshot = 0
    for _ in 0..<100 {
        let k = Int(random.next() % 1_001)
        let previous = tl.step
        try tl.seek(to: k)
        #expect(tl.state.checksum() == fresh.checksums[k] && tl.hash == fresh.hashes[k])
        if tl.ring.latest(atOrBefore: k) != nil {
            #expect(tl.replayedStepCount <= 63)
            maxFromSnapshot = max(maxFromSnapshot, tl.replayedStepCount)
        } else {
            #expect(tl.replayedStepCount <= (previous <= k ? k - previous : k))
        }
    }
    #expect(maxFromSnapshot <= 63)
}

@Test func timelineRefusesBadStepsAndRings() throws {
    var tl = try timeline(seededCommands())
    try tl.advance(steps: 10)
    #expect(throws: TimelineError.negativeStep) { try tl.seek(to: -1) }
    #expect(throws: TimelineError.stepLimit(10_000_001)) { try tl.seek(to: 10_000_001) }
    #expect(throws: TimelineError.negativeStep) { try tl.advance(steps: -1) }
    #expect(throws: TimelineError.stepLimit(10_000_010)) { try tl.advance(steps: 10_000_000) }
    #expect(throws: TimelineError.negativeStep) { try tl.insert(.push(1), at: -2) }
    #expect(tl.step == 10)
    #expect(throws: TimelineError.ringSize(0)) {
        try ReversibleTimeline<Drift, Nudge>(start: Drift(), capacity: 0, apply: applyNudge)
    }
    #expect(throws: TimelineError.interval(65_537)) {
        try ReversibleTimeline<Drift, Nudge>(start: Drift(), interval: 65_537, apply: applyNudge)
    }
}

/// Counts every `step` call across all copies; shared by reference, so restored copies see later counts.
private final class StepCounter: @unchecked Sendable { var calls: UInt64 = 0 }

/// A non-deterministic simulation: its checksum reads the shared live step counter.
private struct LiveCounted: FixedStepSimulation, Sendable {
    let counter: StepCounter
    var x = 0.0
    mutating func step(_ dt: Double) { counter.calls += 1; x += dt }
    func checksum() -> UInt64 { fnv([x.bitPattern, counter.calls]) }
}

/// A non-deterministic simulation: each step stamps the shared step counter into the state.
private struct Stamped: FixedStepSimulation, Sendable {
    let counter: StepCounter
    var stamp: UInt64 = 0
    mutating func step(_ dt: Double) { counter.calls += 1; stamp = counter.calls }
    func checksum() -> UInt64 { stamp }
}

@Test func timelineReportsANonDeterministicSimulationOnBackwardSeek() throws {
    var tl = try ReversibleTimeline<LiveCounted, Nudge>(start: LiveCounted(counter: StepCounter()), interval: 64,
                                                        apply: { _, _ in })
    try tl.advance(steps: 200)
    let (step, hash, x, kept) = (tl.step, tl.hash, tl.state.x, tl.ring.snapshots.map(\.step))
    for k in [100, 64, 10] {
        #expect(throws: TimelineError.hashMismatch) { try tl.seek(to: k) }
        #expect(tl.step == step && tl.hash == hash && tl.state.x == x && tl.ring.snapshots.map(\.step) == kept)
    }
}

@Test func timelineReportsANonDeterministicReplayThroughAKeptSnapshot() throws {
    var tl = try ReversibleTimeline<Stamped, Nudge>(start: Stamped(counter: StepCounter()), interval: 64,
                                                    apply: { _, _ in })
    try tl.advance(steps: 200)
    try tl.seek(to: 10)
    let (hash, stamp) = (tl.hash, tl.state.stamp)
    #expect(throws: TimelineError.hashMismatch) { try tl.advance(steps: 140) }
    #expect(tl.step == 10 && tl.hash == hash && tl.state.stamp == stamp && tl.ring.snapshots.map(\.step) == [64, 128, 192])
}
