// AmethystEscapeCrystal — feature 361 (R02-G07-01) T-R02G0701-002 (FR-R02G0701-002, 003, 005; clarification Q2). The
// crystal's state: every shell's offset (0 … N − 1) and the pearl's pocket (shell, absolute sector). A pocket (r, a) lies
// in shell r's own sector (a − o_r) mod N. Rotating shell r by ±1 changes o_r by ±1 mod N and turns the pearl with it when
// the pearl is in shell r. The advance makes exactly one transition from (r, a) with own sector j: when j is an outer
// aperture of shell r the pearl leaves through the exit gap (the outermost shell) or moves to (r + 1, a); otherwise, when
// wall j is absent, it moves to (r, a + 1 mod N); otherwise it is stuck. A move that lands on a blocked wedge (the
// destination's own sector in its shell's blocked set) is a wedge. Which pockets connect depends only on the current
// offsets, so nothing is cached across rotations. Integers only; no clock, no random source.

/// A pocket: a shell and an absolute sector.
public struct AmethystEscapePocket: Sendable, Hashable, Codable {
    /// The shell, 0 (innermost) … K − 1.
    public let shell: Int
    /// The absolute sector, 0 … N − 1.
    public let sector: Int

    /// A pocket (not checked).
    public init(shell: Int, sector: Int) {
        self.shell = shell
        self.sector = sector
    }
}

/// The one transition an advance makes.
public enum AmethystEscapeTransition: Sendable, Equatable {
    /// The pearl moves to the pocket.
    case moved(AmethystEscapePocket)
    /// The pearl leaves the outermost shell through the exit gap.
    case exited
    /// The pearl moves into the pocket, which is a blocked wedge.
    case wedge(AmethystEscapePocket)
    /// No aperture is lined up and a radial wall stands ahead: no move.
    case stuck
}

/// The shell offsets and the pearl's pocket.
public struct AmethystEscapeCrystal: Sendable, Hashable, Codable {
    /// Every shell's offset, 0 … N − 1, innermost first.
    public private(set) var offsets: [Int]
    /// The pearl's pocket.
    public private(set) var pearl: AmethystEscapePocket

    /// The level's opening crystal: every offset 0 and the pearl at its start in shell 0.
    public init(level: AmethystEscapeLevel) {
        offsets = Array(repeating: 0, count: level.shells.count)
        pearl = AmethystEscapePocket(shell: 0, sector: level.start)
    }

    /// A crystal of the given values (not checked).
    public init(offsets: [Int], pearl: AmethystEscapePocket) {
        self.offsets = offsets
        self.pearl = pearl
    }

    /// The own sector of `pocket` in its shell: (sector − offset) mod N.
    public func ownSector(_ pocket: AmethystEscapePocket, level: AmethystEscapeLevel) -> Int {
        Self.modulo(pocket.sector - offsets[pocket.shell], level.sectors)
    }

    /// Whether `pocket` is a blocked wedge under the current offsets.
    public func isBlocked(_ pocket: AmethystEscapePocket, level: AmethystEscapeLevel) -> Bool {
        level.shells[pocket.shell].isBlocked(ownSector(pocket, level: level))
    }

    /// This crystal with shell `shell` turned by `step` (+1 clockwise, −1 anticlockwise); the pearl turns with it when
    /// it is in that shell. Steps other than ±1 and shells out of range are the caller's to refuse.
    public func rotating(shell: Int, step: Int, level: AmethystEscapeLevel) -> Self {
        var next = self
        next.offsets[shell] = Self.modulo(offsets[shell] + step, level.sectors)
        if pearl.shell == shell {
            next.pearl = AmethystEscapePocket(shell: shell, sector: Self.modulo(pearl.sector + step, level.sectors))
        }
        return next
    }

    /// The one transition of an advance from the current state (clarification Q2).
    public func transition(level: AmethystEscapeLevel) -> AmethystEscapeTransition {
        let shell = level.shells[pearl.shell]
        let own: Int = ownSector(pearl, level: level)
        let destination: AmethystEscapePocket
        if shell.isOpen(own) {
            if pearl.shell == level.outermost { return .exited }
            destination = AmethystEscapePocket(shell: pearl.shell + 1, sector: pearl.sector)
        } else if !shell.hasWall(own) {
            destination = AmethystEscapePocket(shell: pearl.shell, sector: Self.modulo(pearl.sector + 1, level.sectors))
        } else {
            return .stuck
        }
        return isBlocked(destination, level: level) ? .wedge(destination) : .moved(destination)
    }

    /// This crystal with the pearl in `pocket` (after a `moved` or `wedge` transition).
    public func placing(pearl pocket: AmethystEscapePocket) -> Self {
        var next = self
        next.pearl = pocket
        return next
    }

    /// `value` mod `n` in 0 ..< n.
    static func modulo(_ value: Int, _ n: Int) -> Int {
        ((value % n) + n) % n
    }
}

/// A player action: turn a shell by one sector (+1 clockwise, −1 anticlockwise) or advance the pearl.
public enum AmethystEscapeAction: Sendable, Hashable, Codable {
    /// Turn shell (first) by step (second), ±1.
    case rotate(Int, Int)
    /// Advance the pearl by one transition.
    case advance
}
