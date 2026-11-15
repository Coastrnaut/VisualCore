// WaveDirector — feature 076 (A10-P02) T-A10-202 (FR-A10-201–204, FR-A10-210, FR-A10-211; clarifications 1–3;
// research D1, D3). Decides, once per played step, which objects spawn, and runs the waves. A wave lasts 600 steps
// (10 s); wave 1 starts at run step 0 with `rain`; its wave step runs 0…599. `step(_:random:)` does, in this order:
// 1. Spawns at the current wave step s with the wave's ``Difficulty`` (none before s = 30):
//    - `rain`, when (s − 30) is a multiple of the spawn gap: draws the lane (one value, uniform 0…4) and the kind
//      (one value, hazard below 0.7); the item is left to the simulation (`contentId` nil).
//    - `wall`, when (s − 30) is a multiple of 120: draws the free lane (one value, uniform among the lanes other than
//      the previous free lane, or all five when there is none) and the row's fall speed (one value, uniform in the
//      wave's range); four spike-ball requests of radius 0.5 sharing that speed in lane order; the free lane is saved.
//    - `zigzag`, at every spawn gap: a spike-ball in lane `cursor ≤ 4 ? cursor : 8 − cursor`; the cursor steps
//      0…7 and wraps (no draw).
//    - `orb-trail`, at every spawn gap: a glow-orb in the trail lane (the cursor, drawn when the wave began); at
//      every second gap (odd spawn index) bars in the neighbouring lanes, lower lane first (no draw).
// 2. The wave step increases; at 600 the next wave begins: wave + 1, wave step 0, the cursor 0, and the pattern
//    drawn (one value, uniform among the table's patterns other than the previous wave's); for `orb-trail` the trail
//    lane is drawn next (one value, uniform 0…4) into the cursor. The previous free lane is kept.
// The simulation then makes one object per request, in request order, with its own draws. Every request starts at a
// lane centre (`Lanes.centre`). Reachability of a wall's free lane (research D3): the player crosses the widest
// distance in the field (0.5 → 8.1, 7.6 units) in under 1 s (60 units/s² to 9 units/s), while a row needs at least
// (16.5 − 1.5 − 0.9) / 5 ≈ 2.8 s to reach the player.
import Foundation
import VisualCoreSimulation

/// One object the wave director asks the simulation to spawn.
public struct SpawnRequest: Equatable, Sendable {
    /// The lane (0…4); the object starts at ``Lanes/centre(_:)`` of it.
    public var lane: Int
    /// Hazard or orb.
    public var kind: ObjectKind
    /// The catalog item, or nil when the simulation draws an item of ``kind``.
    public var contentId: String?
    /// A fixed radius (wall spike-balls 0.5), or nil to draw from the item's radius range.
    public var radius: Double?
    /// A fixed fall speed in units per second (a wall row's shared speed), or nil to draw from the wave's range.
    public var fallSpeed: Double?

    /// Creates a request.
    public init(lane: Int, kind: ObjectKind, contentId: String? = nil, radius: Double? = nil,
                fallSpeed: Double? = nil) {
        self.lane = lane; self.kind = kind; self.contentId = contentId; self.radius = radius
        self.fallSpeed = fallSpeed
    }
}

/// Runs the waves of a Neon Dodge run and decides its spawns.
public enum WaveDirector {
    /// The length of a wave in steps (10 s).
    public static let waveLength = 600
    /// The wave step of a wave's first spawn.
    public static let firstSpawnStep = 30
    /// The chance that a rain spawn is a hazard (else an orb).
    public static let rainHazardChance = 0.7
    /// The radius of a wall's spike-balls.
    public static let wallRadius = 0.5
    /// The content of wall and zigzag hazards.
    public static let spikeBallId = "spike-ball"
    /// The content of the trail's guards.
    public static let barId = "bar"
    /// The content of the trail's orbs.
    public static let orbId = "glow-orb"
    /// The number of zigzag cursor positions (lanes 0, 1, 2, 3, 4, 3, 2, 1).
    public static let zigzagCycle = 8

    /// The lane of zigzag cursor position `cursor` (0…7).
    public static func zigzagLane(_ cursor: Int) -> Int {
        let c = ((cursor % zigzagCycle) + zigzagCycle) % zigzagCycle
        return c <= Lanes.count - 1 ? c : zigzagCycle - c
    }

    /// The index of the spawn at wave step `waveStep` for a pattern spawning every `every` steps from step 30, or
    /// nil when no spawn is due.
    public static func spawnIndex(waveStep: Int, every: Int) -> Int? {
        guard every > 0, waveStep >= firstSpawnStep, (waveStep - firstSpawnStep) % every == 0 else { return nil }
        return (waveStep - firstSpawnStep) / every
    }

    /// A uniform index below `count` from one generator value.
    static func index(_ count: Int, _ random: inout SeededRandom) -> Int {
        min(Int(random.double() * Double(count)), count - 1)
    }

    /// Runs one played step of `run`'s wave (see the file header for the order and the draws) and returns the spawns
    /// due at this step. Only the wave fields of `run` change.
    public static func step(_ run: inout GameRun, random: inout SeededRandom) -> [SpawnRequest] {
        let difficulty = Difficulty(wave: run.wave)
        let s = run.waveStep
        var requests: [SpawnRequest] = []
        switch PatternTable.pattern(id: run.patternId)?.rule ?? .rain {
        case .rain:
            if spawnIndex(waveStep: s, every: difficulty.spawnGap) != nil {
                let lane = index(Lanes.count, &random)
                let kind: ObjectKind = random.double() < rainHazardChance ? .hazard : .orb
                requests.append(SpawnRequest(lane: lane, kind: kind))
            }
        case .wall:
            let every = PatternTable.pattern(id: run.patternId)?.rowEvery ?? 120
            if spawnIndex(waveStep: s, every: every) != nil {
                let candidates = (0..<Lanes.count).filter { $0 != run.freeLane }
                let free = candidates[index(candidates.count, &random)]
                let speed = random.range(difficulty.fallSpeed)
                for lane in 0..<Lanes.count where lane != free {
                    requests.append(SpawnRequest(lane: lane, kind: .hazard, contentId: spikeBallId,
                                                 radius: wallRadius, fallSpeed: speed))
                }
                run.freeLane = free
            }
        case .zigzag:
            if spawnIndex(waveStep: s, every: difficulty.spawnGap) != nil {
                let cursor = min(max(run.patternCursor, 0), zigzagCycle - 1)
                requests.append(SpawnRequest(lane: zigzagLane(cursor), kind: .hazard, contentId: spikeBallId))
                run.patternCursor = (cursor + 1) % zigzagCycle
            }
        case .orbTrail:
            if let n = spawnIndex(waveStep: s, every: difficulty.spawnGap) {
                let lane = min(max(run.patternCursor, 0), Lanes.count - 1)
                requests.append(SpawnRequest(lane: lane, kind: .orb, contentId: orbId))
                if n % 2 == 1 {
                    for guardLane in [lane - 1, lane + 1] where Lanes.contains(guardLane) {
                        requests.append(SpawnRequest(lane: guardLane, kind: .hazard, contentId: barId))
                    }
                }
            }
        }
        run.waveStep = s + 1
        if run.waveStep >= waveLength { beginNextWave(&run, random: &random) }
        return requests
    }

    /// Starts the next wave of `run`: wave + 1, wave step 0, cursor 0, the pattern drawn among the others, and for
    /// `orb-trail` the trail lane drawn into the cursor.
    static func beginNextWave(_ run: inout GameRun, random: inout SeededRandom) {
        let others = PatternTable.bundled.filter { $0.id != run.patternId }
        let next = others[index(others.count, &random)]
        run.wave += 1
        run.waveStep = 0
        run.patternId = next.id
        run.patternCursor = 0
        if next.rule == .orbTrail { run.patternCursor = index(Lanes.count, &random) }
    }
}
