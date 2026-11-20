// PlantTurtle — feature 219 (R02-F19) T-R02F19-003 (FR-R02F19-001, 002; SC-R02F19-001; clarifications Q1, Q2; research R1, R2).
// Rewrites a `PlantGrammar` into its word and reads the word with a 3-D turtle (Prusinkiewicz and Lindenmayer, The
// Algorithmic Beauty of Plants, 1990).
//
// Derivation: one `SeededRandom(seed: grammar.seed)` stream for the whole derivation. In each generation the word is
// read left to right; a symbol without a rule is kept, a symbol whose rule has one successor is replaced without a draw,
// and a symbol whose rule has n > 1 successors draws one u = `double()` in [0, 1) and takes the first successor i whose
// cumulative weight (w₀ + … + wᵢ) / (w₀ + … + wₙ₋₁) exceeds u; the last successor takes any rounding remainder. A word
// that would pass `PlantGrammar.maxWord` symbols is never built: the derivation stops appending and refuses with
// `.wordLimit(n)`, n the length the next word would have had.
//
// Turtle: it starts at the origin with heading H = +y, left L = −x and up U = +z (U = H × L), radius `grammar.radius`
// and bracket depth 0. Every turn is a right-handed rotation by Rodrigues' formula, followed by re-orthonormalisation
// (H normalised, L made orthogonal to H and normalised, U = H × L):
//   F  draws a branch from the position to position + H · step at the current radius and depth, then moves there;
//   f  moves by H · step without drawing;
//   +  turns left: H and L rotate about U by +δ (so H moves towards L); − (or ASCII -) turns right by −δ;
//   &  pitches down: H and U rotate about L by +δ (so H moves towards −U); ^ pitches up by −δ;
//   \  rolls left: L and U rotate about H by +δ (so L moves towards U); / rolls right by −δ;
//   |  turns around: H and L rotate about U by π (both negated exactly);
//   [  pushes the whole state, ] pops it (the depth is the number of open brackets);
//   !  multiplies the radius by `grammar.radiusFactor`;
//   P, C, L record a petal, cap or leaf marker at the position with the frame (H, L, U) and size = step.
// Every other character does nothing. A word whose brackets do not balance is refused with `.brackets`, and one with
// more than `PlantGrammar.maxBranches` F symbols with `.branchLimit(n)`, n the number of F symbols, before any geometry.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Rewrites a grammar's start word through its generations.
public enum LSystem {
    /// The word after `grammar.generations` rewrites of `grammar.start`, with weighted choices drawn from one seeded
    /// stream in reading order (see the file header for the exact rule); refuses a word longer than
    /// ``PlantGrammar/maxWord`` with ``PlantError/wordLimit(_:)``.
    public static func derive(_ grammar: PlantGrammar) throws(PlantError) -> String {
        var alphabet: [Character] = []
        var ids: [Character: Int32] = [:]
        func id(_ symbol: Character) -> Int32 {
            if let known = ids[symbol] { return known }
            let next = Int32(alphabet.count)
            alphabet.append(symbol)
            ids[symbol] = next
            return next
        }

        var word: [Int32] = []
        word.reserveCapacity(grammar.start.count)
        for symbol in grammar.start { word.append(id(symbol)) }

        // Compiled rules: successor words as symbol ids and cumulative weight fractions.
        var predecessors: [Int32] = []
        var successorWords: [[[Int32]]] = []
        var cumulative: [[Double]] = []
        var longest = 1
        for rule in grammar.rules {
            predecessors.append(id(rule.predecessor))
            var words: [[Int32]] = []
            var total = 0.0
            for successor in rule.successors {
                var compiled: [Int32] = []
                for symbol in successor.word { compiled.append(id(symbol)) }
                longest = max(longest, compiled.count)
                words.append(compiled)
                total += successor.weight
            }
            var fractions: [Double] = []
            var running = 0.0
            for successor in rule.successors {
                running += successor.weight
                fractions.append(running / total)
            }
            successorWords.append(words)
            cumulative.append(fractions)
        }
        var ruleOf = [Int](repeating: -1, count: alphabet.count)
        for (index, predecessor) in predecessors.enumerated() { ruleOf[Int(predecessor)] = index }

        var random = SeededRandom(seed: grammar.seed)
        for _ in 0..<grammar.generations {
            var next: [Int32] = []
            next.reserveCapacity(min(PlantGrammar.maxWord, word.count * longest))
            var length = 0
            var over = false
            for symbol in word {
                let rule = ruleOf[Int(symbol)]
                if rule < 0 {
                    length += 1
                    if length > PlantGrammar.maxWord { over = true }
                    if !over { next.append(symbol) }
                    continue
                }
                let words = successorWords[rule]
                var chosen = 0
                if words.count > 1 {
                    let u = random.double()
                    let fractions = cumulative[rule]
                    chosen = words.count - 1
                    for index in 0..<(words.count - 1) where fractions[index] > u {
                        chosen = index
                        break
                    }
                }
                length += words[chosen].count
                if length > PlantGrammar.maxWord { over = true }
                if !over { next.append(contentsOf: words[chosen]) }
            }
            if over { throw .wordLimit(length) }
            word = next
        }

        var result = String()
        result.reserveCapacity(word.count)
        for symbol in word { result.append(alphabet[Int(symbol)]) }
        return result
    }
}

/// One drawn segment of a plant.
public struct PlantBranch: Sendable, Equatable {
    /// Where the segment starts.
    public let start: Vec3
    /// Where the segment ends.
    public let end: Vec3
    /// The branch radius when it was drawn.
    public let radius: Double
    /// The bracket depth when it was drawn (0 for the trunk).
    public let depth: Int
}

/// The kind of part placed at a marker.
public enum PlantPart: String, Sendable, Codable, CaseIterable {
    /// A petal (symbol `P`).
    case petal
    /// A cap (symbol `C`).
    case cap
    /// A leaf (symbol `L`).
    case leaf
}

/// A place where a part is attached, with the turtle's orthonormal frame there.
public struct PlantMarker: Sendable, Equatable {
    /// The part to place.
    public let kind: PlantPart
    /// The turtle position.
    public let position: Vec3
    /// The turtle heading H.
    public let heading: Vec3
    /// The turtle left vector L.
    public let left: Vec3
    /// The turtle up vector U = H × L.
    public let up: Vec3
    /// The part size (the grammar's step).
    public let size: Double
}

/// The branches and markers of a plant, in word order.
public struct PlantSkeleton: Sendable, Equatable {
    /// The drawn segments.
    public let branches: [PlantBranch]
    /// The part markers.
    public let markers: [PlantMarker]
}

/// Reads a word with a 3-D turtle (sign conventions in the file header).
public enum PlantTurtle {
    private struct State {
        var position: Vec3
        var heading: Vec3
        var left: Vec3
        var up: Vec3
        var radius: Double
    }

    /// The skeleton drawn by `word` with the grammar's angle, step, radius and radius factor; refuses unbalanced brackets
    /// with ``PlantError/brackets`` and more than ``PlantGrammar/maxBranches`` branches with ``PlantError/branchLimit(_:)``.
    public static func interpret(_ word: String, grammar: PlantGrammar) throws(PlantError) -> PlantSkeleton {
        var open = 0
        var draws = 0
        for symbol in word {
            switch symbol {
            case "[": open += 1
            case "]":
                open -= 1
                if open < 0 { throw .brackets }
            case "F": draws += 1
            default: break
            }
        }
        if open != 0 { throw .brackets }
        if draws > PlantGrammar.maxBranches { throw .branchLimit(draws) }

        let delta = grammar.angle
        let step = grammar.step
        var state = State(position: .zero, heading: Vec3(0, 1, 0), left: Vec3(-1, 0, 0), up: Vec3(0, 0, 1),
                          radius: grammar.radius)
        var stack: [State] = []
        var branches: [PlantBranch] = []
        branches.reserveCapacity(draws)
        var markers: [PlantMarker] = []

        for symbol in word {
            switch symbol {
            case "F":
                let end = state.position + state.heading * step
                branches.append(PlantBranch(start: state.position, end: end, radius: state.radius, depth: stack.count))
                state.position = end
            case "f":
                state.position = state.position + state.heading * step
            case "+":
                turn(&state, by: delta)
            case "-", "\u{2212}":
                turn(&state, by: -delta)
            case "&":
                pitch(&state, by: delta)
            case "^":
                pitch(&state, by: -delta)
            case "\\":
                roll(&state, by: delta)
            case "/":
                roll(&state, by: -delta)
            case "|":
                state.heading = -state.heading
                state.left = -state.left
                orthonormalise(&state)
            case "[":
                stack.append(state)
            case "]":
                state = stack.removeLast()
            case "!":
                state.radius *= grammar.radiusFactor
            case "P", "C", "L":
                let kind: PlantPart = symbol == "P" ? .petal : (symbol == "C" ? .cap : .leaf)
                markers.append(PlantMarker(kind: kind, position: state.position, heading: state.heading,
                                           left: state.left, up: state.up, size: step))
            default:
                break
            }
        }
        return PlantSkeleton(branches: branches, markers: markers)
    }

    /// Derives the grammar's word with ``LSystem/derive(_:)`` and interprets it with ``interpret(_:grammar:)``.
    public static func grow(_ grammar: PlantGrammar) throws(PlantError) -> PlantSkeleton {
        try interpret(try LSystem.derive(grammar), grammar: grammar)
    }

    /// Rodrigues' rotation of `v` about the unit `axis` by `angle` (right-handed).
    private static func rotate(_ v: Vec3, about axis: Vec3, by angle: Double) -> Vec3 {
        let c = cos(angle)
        let s = sin(angle)
        return v * c + axis.cross(v) * s + axis * (axis.dot(v) * (1 - c))
    }

    private static func turn(_ state: inout State, by angle: Double) {
        state.heading = rotate(state.heading, about: state.up, by: angle)
        state.left = rotate(state.left, about: state.up, by: angle)
        orthonormalise(&state)
    }

    private static func pitch(_ state: inout State, by angle: Double) {
        state.heading = rotate(state.heading, about: state.left, by: angle)
        state.up = rotate(state.up, about: state.left, by: angle)
        orthonormalise(&state)
    }

    private static func roll(_ state: inout State, by angle: Double) {
        state.left = rotate(state.left, about: state.heading, by: angle)
        state.up = rotate(state.up, about: state.heading, by: angle)
        orthonormalise(&state)
    }

    /// Gram–Schmidt on heading then left; up = heading × left.
    private static func orthonormalise(_ state: inout State) {
        let h = state.heading.normalized
        let l = (state.left - h * state.left.dot(h)).normalized
        state.heading = h
        state.left = l
        state.up = h.cross(l)
    }
}
