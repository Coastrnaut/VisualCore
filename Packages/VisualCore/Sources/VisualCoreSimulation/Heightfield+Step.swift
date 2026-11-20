// Heightfield+Step — feature 217 (R02-F17) T-R02F17-003…005 (FR-R02F17-002…005; clarifications Q2–Q4; research
// R2–R6). One frame step of the virtual-pipe shallow-water model (O'Brien and Hodgins 1995; Mei, Decaudin and Hu 2007).
//
// Bounds: a frame time Δ is split into n = ⌈Δ / h⌉ sub-steps of Δ / n, h = min(maxSubstep, 0.25 / √(g · depth_max)) the
// stability limit for the deepest water at the start of the frame (cell size 1); past maxSubsteps, that many sub-steps
// of h run and the rest of Δ is reported as dropped.
//
// A sub-step: (1) every edge flux becomes max(0, damping · f + h · A · g · Δs), Δs the drop of surface (terrain + water)
// to the neighbour (the cell's own water depth across an open border, 0 towards a wall), clamped to 0 … maxFlux;
// (2) the wanted outflow f · h is turned into whole quanta (floor) and, when a cell's wanted total exceeds its water,
// every direction is scaled by water / total (floor; the fluxes by the same factor); (3) dye and sediment leave in the
// same proportion as the water, floor(amount · sent / water) in full-width integer arithmetic, and a cell that sends all its water sends the remainder
// too, along its largest outflow, so no dry cell keeps dye or sediment; (4) every cell sends
// from its start-of-sub-step amounts and every neighbour receives, the border's share counted as drained; (5) when
// erosion is on, each cell compares its sediment with the capacity C = K_c · |v| · max(slope, 0.01) · depth and moves
// whole quanta between rock and sediment within the cell, limited by what is present. Every transfer is an integer
// subtraction and addition of the same value, so every total stays equal to its ledger account; all cells compute from
// the same start-of-phase arrays, so the result does not depend on the order cells are visited.
import Foundation

extension Heightfield {
    /// Advances the model by `time` seconds in bounded sub-steps (see the file header); refuses a negative or non-finite
    /// time with ``HeightfieldError/invalidTime``. A time of 0 does nothing.
    public mutating func step(by time: Double) throws(HeightfieldError) -> HeightfieldStepReport {
        guard time.isFinite, time >= 0 else { throw .invalidTime }
        guard time > 0 else { return HeightfieldStepReport(substeps: 0, substepDuration: 0, droppedTime: 0, fluxClamped: false) }
        let p = parameters
        let deepest = Double(waterQ.max() ?? 0) / Double(Self.quantaPerUnit)
        let limit = min(p.maxSubstep, 0.25 / (p.gravity * max(deepest, 1e-6)).squareRoot())
        let ratio = time / limit
        var count: Int
        var duration: Double
        var dropped = 0.0
        if ratio > Double(p.maxSubsteps) {
            count = p.maxSubsteps
            duration = limit
            dropped = time - Double(count) * limit
        } else {
            count = max(1, Int(ratio.rounded(.up)))
            duration = time / Double(count)
        }
        var clamped = false
        for _ in 0..<count where substep(duration) { clamped = true }
        return HeightfieldStepReport(substeps: count, substepDuration: duration, droppedTime: dropped,
                                     fluxClamped: clamped)
    }

    /// The neighbour of `cell` in direction `d` (up, right, down, left), or −1 across the border.
    func neighbour(_ cell: Int, _ d: Int) -> Int {
        let x = cell % width, y = cell / width
        switch d {
        case 0: return y > 0 ? cell - width : -1
        case 1: return x < width - 1 ? cell + 1 : -1
        case 2: return y < height - 1 ? cell + width : -1
        default: return x > 0 ? cell - 1 : -1
        }
    }

    /// Whole quanta for a non-negative amount in quanta (floor), 0 for anything not finite or not positive.
    static func wholeQuanta(_ value: Double) -> Int64 {
        guard value.isFinite, value > 0 else { return 0 }
        return Int64(min(value, Double(maxAmount)).rounded(.down))
    }

    /// floor(amount · part / whole) without overflow, for 0 ≤ part ≤ whole.
    static func portion(_ amount: Int64, _ part: Int64, _ whole: Int64) -> Int64 {
        guard whole > 0, amount > 0, part > 0 else { return 0 }
        let product = amount.multipliedFullWidth(by: part)
        return whole.dividingFullWidth((high: product.high, low: product.low)).quotient
    }

    /// One sub-step of `h` seconds; returns whether a flux was clamped. The arrays are moved out of the value for the
    /// sub-step and walked through unsafe buffers (no copy or bounds check per cell); the arithmetic and its order are
    /// those of the file header.
    mutating func substep(_ h: Double) -> Bool {
        let p = parameters
        let cells = cellCount
        let w = width
        let rows = height
        let open = edges == .open
        let unit = Double(Self.quantaPerUnit)
        let channels = dyeChannels
        let maxFlux = Self.maxFlux
        var clamped = false
        var sends = [Int64](repeating: 0, count: cells * 4)
        let terrain = terrainQ
        let startWater = waterQ
        let startSediment = sedimentQ
        let startDye = dyeQ
        var water = waterQ
        var sediment = sedimentQ
        var dye = dyeQ
        var flux = fluxes
        waterQ = []
        sedimentQ = []
        dyeQ = []
        fluxes = []
        var drainedWater: Int64 = 0
        var drainedRock: Int64 = 0
        var drainedDye = [Int64](repeating: 0, count: channels)

        terrain.withUnsafeBufferPointer { T in
        startWater.withUnsafeBufferPointer { W0 in
        startSediment.withUnsafeBufferPointer { S0 in
        startDye.withUnsafeBufferPointer { D0 in
        water.withUnsafeMutableBufferPointer { W in
        sediment.withUnsafeMutableBufferPointer { S in
        dye.withUnsafeMutableBufferPointer { D in
        flux.withUnsafeMutableBufferPointer { F in
        sends.withUnsafeMutableBufferPointer { O in
            /// The neighbour of `c` in direction `d` (up, right, down, left), or −1 across the border.
            func neighbour(_ c: Int, _ d: Int) -> Int {
                let x = c % w, y = c / w
                switch d {
                case 0: return y > 0 ? c - w : -1
                case 1: return x < w - 1 ? c + 1 : -1
                case 2: return y < rows - 1 ? c + w : -1
                default: return x > 0 ? c - 1 : -1
                }
            }
            /// What is left of `amount` after the shares of every outflow of `c` except `except`.
            func remainder(_ amount: Int64, _ c: Int, except: Int) -> Int64 {
                var left = amount
                for d in 0..<4 where d != except { left -= Heightfield.portion(amount, O[c * 4 + d], W0[c]) }
                return left
            }

            // (1) fluxes and (2) whole-quantum outflows, from start-of-sub-step amounts.
            for c in 0..<cells {
                let surface = Double(T[c] + W0[c]) / unit
                var total: Int64 = 0
                for d in 0..<4 {
                    let n = neighbour(c, d)
                    let drop: Double
                    if n >= 0 {
                        drop = surface - Double(T[n] + W0[n]) / unit
                    } else if open {
                        drop = Double(W0[c]) / unit
                    } else {
                        F[c * 4 + d] = 0
                        continue
                    }
                    var f = p.damping * F[c * 4 + d] + h * p.pipeArea * p.gravity * drop
                    if !f.isFinite {
                        f = 0
                        clamped = true
                    }
                    if f < 0 { f = 0 }
                    if f > maxFlux {
                        f = maxFlux
                        clamped = true
                    }
                    F[c * 4 + d] = f
                    let wanted = Heightfield.wholeQuanta(f * h * unit)
                    O[c * 4 + d] = wanted
                    total += wanted
                }
                if total > W0[c] {
                    let factor = Double(W0[c]) / Double(total)
                    for d in 0..<4 {
                        O[c * 4 + d] = Heightfield.portion(O[c * 4 + d], W0[c], total)
                        F[c * 4 + d] *= factor
                    }
                }
            }

            // (3) dye and sediment leave with the water, (4) everything is applied. A cell that sends all its water
            // also sends the rounding remainder of its dye and sediment along its largest outflow (the first of equal
            // ones), so a dry cell never keeps either; that outflow is applied last.
            for c in 0..<cells where W0[c] > 0 {
                var sentTotal: Int64 = 0
                var largest = 0
                for d in 0..<4 {
                    sentTotal += O[c * 4 + d]
                    if O[c * 4 + d] > O[c * 4 + largest] { largest = d }
                }
                guard sentTotal > 0 else { continue }
                let empties = sentTotal == W0[c]
                for step in 0..<4 {
                    let d = step == 3 ? largest : (step < largest ? step : step + 1)
                    let sent = O[c * 4 + d]
                    guard sent > 0 else { continue }
                    let n = neighbour(c, d)
                    let last = empties && d == largest
                    let carried = last ? remainder(S0[c], c, except: d) : Heightfield.portion(S0[c], sent, W0[c])
                    W[c] -= sent
                    S[c] -= carried
                    if n >= 0 {
                        W[n] += sent
                        S[n] += carried
                    } else {
                        drainedWater += sent
                        drainedRock += carried
                    }
                    for k in 0..<channels {
                        let index = k * cells + c
                        let moved = last ? remainder(D0[index], c, except: d)
                                         : Heightfield.portion(D0[index], sent, W0[c])
                        D[index] -= moved
                        if n >= 0 {
                            D[k * cells + n] += moved
                        } else {
                            drainedDye[k] += moved
                        }
                    }
                }
            }
        }}}}}}}}}

        waterQ = water
        sedimentQ = sediment
        dyeQ = dye
        fluxes = flux
        ledger.water.drained += drainedWater
        ledger.rock.drained += drainedRock
        for k in 0..<channels { ledger.dye[k].drained += drainedDye[k] }

        // (5) erosion: an in-cell exchange of whole quanta between rock and sediment.
        if p.erosion { erode(h) }
        return clamped
    }

    /// Exchanges rock and sediment in every cell for a sub-step of `h` seconds (see the file header).
    mutating func erode(_ h: Double) {
        let p = parameters
        let unit = Double(Self.quantaPerUnit)
        let rock = terrainQ
        func outflow(_ cell: Int, _ d: Int) -> Double { cell >= 0 ? fluxes[cell * 4 + d] : 0 }
        func height(_ cell: Int, else fallback: Int) -> Double { Double(rock[cell >= 0 ? cell : fallback]) / unit }
        for c in 0..<cellCount {
            let depth = Double(waterQ[c]) / unit
            let up = neighbour(c, 0), right = neighbour(c, 1), down = neighbour(c, 2), left = neighbour(c, 3)
            let across = (outflow(left, 1) - outflow(c, 3) + outflow(c, 1) - outflow(right, 3)) / 2
            let along = (outflow(up, 2) - outflow(c, 0) + outflow(c, 2) - outflow(down, 0)) / 2
            let speed = depth > 1e-4 ? min((across * across + along * along).squareRoot() / depth, 1_000) : 0
            let sx = (height(right, else: c) - height(left, else: c)) / 2
            let sy = (height(down, else: c) - height(up, else: c)) / 2
            let steepness = (sx * sx + sy * sy).squareRoot() / (1 + sx * sx + sy * sy).squareRoot()
            let capacity = p.capacity * speed * max(steepness, 0.01) * depth
            let suspended = Double(sedimentQ[c]) / unit
            if suspended < capacity {
                let amount = min(Self.wholeQuanta(p.dissolving * (capacity - suspended) * h * unit), terrainQ[c])
                terrainQ[c] -= amount
                sedimentQ[c] += amount
            } else {
                let amount = min(Self.wholeQuanta(p.depositing * (suspended - capacity) * h * unit), sedimentQ[c])
                sedimentQ[c] -= amount
                terrainQ[c] += amount
            }
        }
    }
}
