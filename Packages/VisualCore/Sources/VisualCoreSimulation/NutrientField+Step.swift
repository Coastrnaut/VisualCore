// NutrientField+Step — feature 221 (R02-F21) T-R02F21-003 (FR-R02F21-001…003, 006; clarifications Q2, Q3; research
// R2, R3). One frame step of the nutrient field.
//
// Bounds: a frame time t (finite, ≥ 0) above 0.25 s is cut to 0.25 s; it is split into n = max(1, ⌈8 · t · Dmax⌉)
// equal sub-steps of h = t / n (Dmax the largest channel rate). Past 256 sub-steps, n is 256 and t is cut to
// 256 / (8 · Dmax), so r = D · h ≤ 1/8 always; everything not simulated is reported as dropped.
//
// A sub-step, in order: (1) sources and sinks in the order they were added: each moves ⌊carry + rate · unit · h⌋ quanta
// and keeps the fraction as its carry; a source adds at most what the cell and grid limits allow (the rest is capped),
// a sink takes at most what the cell holds (the rest is short); (2) diffusion of every channel with D > 0: every edge
// between 4-neighbours carries ⌊r · |a − b|⌋ quanta from the fuller cell to the emptier, all computed from the
// sub-step's start, so a cell sends at most 4 r ≤ ½ of its excess over each neighbour, never goes negative, the largest
// value never rises and the smallest never falls; the walls are closed; (3) decay of every channel with λ > 0: each cell
// fades ⌊a · (1 − e^(−λh))⌋ quanta. Every transfer is an integer subtraction and addition of the same value and every
// quantum entering or leaving is counted in the ledger, so the totals stay exact. After the sub-steps of a frame with
// t > 0 the growth phase (NutrientField+Growth.swift) runs once.
import Foundation

extension NutrientField {
    /// Advances the field by `time` seconds in bounded sub-steps (see the file header) and reports what happened.
    ///
    /// A time of 0 runs no sub-step and no growth.
    ///
    /// - Throws: `.time` unless `time` is finite and ≥ 0 (nothing changes then).
    public mutating func step(by time: Double) throws(NutrientError) -> NutrientStepReport {
        guard time.isFinite, time >= 0 else { throw .time }
        let zeros = [Int64](repeating: 0, count: channels)
        var t = min(time, Self.maxFrame)
        guard t > 0 else {
            return NutrientStepReport(substeps: 0, simulated: 0, dropped: time - t, added: zeros, removed: zeros,
                                      faded: zeros, eaten: zeros, capped: 0, short: 0, grown: 0)
        }
        let maxD = diffusion.max() ?? 0
        var n = max(1, Int((8 * t * maxD).rounded(.up)))
        if n > Self.maxSubsteps {
            n = Self.maxSubsteps
            t = Double(Self.maxSubsteps) / (8 * maxD)
        }
        let h = t / Double(n)
        let dropped = time - t

        // Work on local copies so the inner loops own their buffers; written back before growth.
        var amounts = amountQ
        amountQ = []
        var totals = totalQ
        var springs = sources
        var added = zeros
        var removed = zeros
        var faded = zeros
        var capped: Int64 = 0
        var short: Int64 = 0
        let count = cellCount
        let w = width
        let ht = height
        let channelCount = channels
        let unit = Double(Self.quantaPerUnit)
        let limit = Self.maxAmount
        var rates: [Double] = []
        var fades: [Double] = []
        for k in 0..<channels {
            rates.append(diffusion[k] * h)
            fades.append(decay[k] > 0 ? -expm1(-decay[k] * h) : 0)
        }
        var delta = [Int64](repeating: 0, count: count)

        for _ in 0..<n {
            // (1) Sources and sinks, in array order.
            for s in 0..<springs.count {
                let q = springs[s].carry + springs[s].rate * unit * h
                let whole = q.rounded(.down)
                springs[s].carry = q - whole
                let move = Int64(whole)
                guard move > 0 else { continue }
                let k = springs[s].channel
                let i = k * count + springs[s].cell
                switch springs[s].kind {
                case .source:
                    let put = max(0, min(move, limit - amounts[i], limit - totals[k]))
                    amounts[i] += put
                    totals[k] += put
                    added[k] += put
                    capped += move - put
                case .sink:
                    let take = min(move, amounts[i])
                    amounts[i] -= take
                    totals[k] -= take
                    removed[k] += take
                    short += move - take
                }
            }
            amounts.withUnsafeMutableBufferPointer { all in
                delta.withUnsafeMutableBufferPointer { cells in
                    guard let first = all.baseAddress, let d = cells.baseAddress else { return }
                    for k in 0..<channelCount {
                        let p = first + k * count
                        // (2) Diffusion from the sub-step's start amounts. Int64(r · (a − b)) truncates toward zero,
                        // so it is ⌊r · |a − b|⌋ carried from the fuller cell to the emptier one.
                        let r = rates[k]
                        if r > 0 {
                            d.update(from: p, count: count)
                            var y = 0
                            while y < ht {
                                let row = y &* w
                                var i = row
                                let last = row &+ w &- 1
                                var a = p[i]
                                while i < last {
                                    let b = p[i &+ 1]
                                    let m = Int64(r * Double(a &- b))
                                    d[i] &-= m
                                    d[i &+ 1] &+= m
                                    a = b
                                    i &+= 1
                                }
                                if y &+ 1 < ht {
                                    i = row
                                    let end = row &+ w
                                    while i < end {
                                        let m = Int64(r * Double(p[i] &- p[i &+ w]))
                                        d[i] &-= m
                                        d[i &+ w] &+= m
                                        i &+= 1
                                    }
                                }
                                y &+= 1
                            }
                            p.update(from: d, count: count)
                        }
                        // (3) Decay.
                        let f = fades[k]
                        if f > 0 {
                            var gone: Int64 = 0
                            var i = 0
                            while i < count {
                                let a = p[i]
                                if a > 0 {
                                    let lost = min(a, max(0, Int64(Double(a) * f)))
                                    p[i] = a &- lost
                                    gone = gone &+ lost
                                }
                                i &+= 1
                            }
                            totals[k] -= gone
                            faded[k] += gone
                        }
                    }
                }
            }
        }

        amountQ = amounts
        totalQ = totals
        sources = springs
        for k in 0..<channels {
            ledger.accounts[k].added += added[k]
            ledger.accounts[k].removed += removed[k]
            ledger.accounts[k].faded += faded[k]
        }
        let growth = growthPhase()
        var eaten = zeros
        if let food = network?.foodChannel, food >= 0, food < channels { eaten[food] = growth.eaten }
        return NutrientStepReport(substeps: n, simulated: t, dropped: dropped, added: added, removed: removed,
                                  faded: faded, eaten: eaten, capped: capped, short: short, grown: growth.grown)
    }
}
