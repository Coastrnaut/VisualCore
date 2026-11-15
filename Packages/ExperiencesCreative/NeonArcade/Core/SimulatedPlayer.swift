// SimulatedPlayer — feature 079 (A10-P05) T-A10-502 (FR-A10-510; clarification 3; research D3; data-model
// "SimulatedPlayer", "BalanceTarget"). Deterministic test players that measure the game's difficulty curve (not
// anyone's ability). Each reads the current `GameRun` and returns a steering value; `play` starts a fresh run with
// `SeededRandom(seed:)`, calls `GameSimulation.steer` whenever the value changes (the `run.steer` action) and
// `GameSimulation.advance` once per step with the bundled catalog, until the run is over or `maxSteps` steps passed.
//   idle      — always 0 (the player rests in the centre lane).
//   dodger    — a threat is a hazard less than 4 units above the player's line and not yet past it (−(r + 0.4) < y −
//               1.5 < 4) whose edge is within 1 unit sideways of the player's edge (|dx| − half-length − r − 0.4 ≤ 1;
//               a circle has half-length 0); the dodger steers fully away from the nearest threat (by distance; to the
//               side with more room when it is straight above, and to the other side when the wall leaves less than
//               1 unit on the away side); with no threat it steers back to the centre lane.
//   collector — as the dodger, but with no threat it steers toward the nearest orb not yet passed (y ≥ 1.5), else to
//               the centre lane.
// Steering toward a point is proportional (dx / 0.5, clamped to −1…1). Balance targets over 20 seeds and at most 6,000
// steps: idle median wave ≤ 2, dodger median wave ≥ 3, collector median score > dodger median score > idle.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Deterministic simulated players for the balance tests.
public enum SimulatedPlayer {
    /// The three players.
    public enum Kind: String, CaseIterable, Sendable {
        /// Never steers.
        case idle
        /// Steers away from threats, else back to the centre lane.
        case dodger
        /// Steers away from threats, else toward the nearest orb.
        case collector
    }

    /// How far above the player a hazard is a threat, in game units.
    public static let lookAhead = 4.0
    /// How far sideways (from the player's edge to the hazard's edge) a hazard is a threat, in game units.
    public static let sideways = 1.0
    /// The distance over which steering toward a point ramps from 0 to full, in game units.
    public static let approach = 0.5
    /// The x of the centre lane (lane 2).
    public static var centreX: Double { Lanes.centre(Lanes.count / 2) }

    /// The steering value `kind` sends for `run` (−1…1).
    public static func steering(_ kind: Kind, run: GameRun) -> Double {
        switch kind {
        case .idle: return 0
        case .dodger: return dodge(run) ?? toward(centreX, from: run.player.x)
        case .collector:
            if let away = dodge(run) { return away }
            return toward(nearestOrb(run)?.position.x ?? centreX, from: run.player.x)
        }
    }

    /// The final run of `kind` playing a fresh run seeded with `seed` for at most `maxSteps` steps (or until over).
    public static func finalRun(_ kind: Kind, seed: UInt64, maxSteps: Int) -> GameRun {
        var run = GameRun.new()
        var random = SeededRandom(seed: seed)
        let catalog = ArcadeCatalog.bundled
        var steps = 0
        while steps < maxSteps, !run.over {
            let value = steering(kind, run: run)
            if value != run.steering { GameSimulation.steer(&run, value: value) }
            GameSimulation.advance(&run, catalog: catalog, random: &random)
            steps += 1
        }
        return run
    }

    /// The wave reached and the score of `kind` playing a fresh run seeded with `seed`
    /// (see ``finalRun(_:seed:maxSteps:)``).
    public static func play(_ kind: Kind, seed: UInt64, maxSteps: Int) -> (waves: Int, score: Int) {
        let run = finalRun(kind, seed: seed, maxSteps: maxSteps)
        return (run.wave, run.score)
    }

    /// The sideways clearance between the player's edge and `object`'s edge (its segment widened by its radius).
    static func clearance(_ object: FallingObject, x: Double) -> Double {
        abs(object.position.x - x) - object.halfLength - object.radius - PlayerState.hitRadius
    }

    /// Full steering away from the nearest threat, or nil when there is none.
    static func dodge(_ run: GameRun) -> Double? {
        let x = run.player.x
        var nearest: (object: FallingObject, distance: Double)?
        for object in run.objects where object.kind == .hazard {
            let dy = object.position.y - GameRun.playerY
            guard dy > -(object.radius + PlayerState.hitRadius), dy < lookAhead,
                  clearance(object, x: x) <= sideways else { continue }
            let d = (object.position - run.player.center).length
            if let best = nearest, best.distance <= d { continue }
            nearest = (object, d)
        }
        guard let threat = nearest?.object else { return nil }
        let room = (left: x - PlayerState.xRange.lowerBound, right: PlayerState.xRange.upperBound - x)
        var direction: Double
        if threat.position.x == x { direction = room.right >= room.left ? 1 : -1 } else {
            direction = x > threat.position.x ? 1 : -1
        }
        if (direction > 0 ? room.right : room.left) < sideways { direction = -direction }
        return direction
    }

    /// The nearest orb not yet passed (y ≥ the player's line), by distance; ties keep the lower id.
    static func nearestOrb(_ run: GameRun) -> FallingObject? {
        let centre = run.player.center
        var best: (object: FallingObject, distance: Double)?
        for object in run.objects where object.kind == .orb && object.position.y >= GameRun.playerY {
            let d = (object.position - centre).length
            if best == nil || d < best!.distance { best = (object, d) }
        }
        return best?.object
    }

    /// Proportional steering from `x` toward `target` (full beyond ``approach``).
    static func toward(_ target: Double, from x: Double) -> Double {
        min(max((target - x) / approach, -1), 1)
    }
}
