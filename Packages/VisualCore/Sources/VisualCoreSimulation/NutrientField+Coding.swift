// NutrientField+Coding — feature 221 (R02-F21) T-R02F21-005 (FR-R02F21-007, 008; clarification Q5; SC-R02F21-006). The
// stored form: JSON schema 1 with sorted keys holding the size, rates, every amount in quanta (one array of cellCount
// values per channel, cell c at index c), the sources with their carries, the bands (null for a channel without one),
// the network (null for none) and the ledger, so a reopened field continues bit-identically. Decoding rebuilds the
// field through its initialisers and setters, so every rule is checked again; a newer schema is refused with
// `.newerSchema(s)` and anything else that is damaged, breaks a rule or does not balance with `.malformed(description)`.
import Foundation

extension NutrientField: Codable {
    // MARK: Stored form

    /// The stored form of one source or sink.
    private struct SourceForm: Codable {
        var cell: Int
        var channel: Int
        var kind: NutrientSourceKind
        var rate: Double
        var carry: Double
    }

    /// The stored form of one viability band.
    private struct BandForm: Codable {
        var low: Double
        var high: Double
        var ramp: Double
    }

    /// The stored form of the growth network; `parents[i]` belongs to `cells[i]`.
    private struct NetworkForm: Codable {
        var limit: Int
        var perFrame: Int
        var threshold: Double
        var foodChannel: Int
        var cost: Int64
        var cells: [Int]
        var parents: [Int]
    }

    /// The whole stored form, schema 1. Every key is required; `network` is written as null when there is none.
    private struct StoredForm: Codable {
        var schema: Int
        var width: Int
        var height: Int
        var channels: Int
        var diffusion: [Double]
        var decay: [Double]
        var amounts: [[Int64]]
        var sources: [SourceForm]
        var bands: [BandForm?]
        var network: NetworkForm?
        var ledger: NutrientLedger

        private enum CodingKeys: String, CodingKey {
            case schema, width, height, channels, diffusion, decay, amounts, sources, bands, network, ledger
        }

        init(schema: Int, width: Int, height: Int, channels: Int, diffusion: [Double], decay: [Double],
             amounts: [[Int64]], sources: [SourceForm], bands: [BandForm?], network: NetworkForm?,
             ledger: NutrientLedger) {
            self.schema = schema
            self.width = width
            self.height = height
            self.channels = channels
            self.diffusion = diffusion
            self.decay = decay
            self.amounts = amounts
            self.sources = sources
            self.bands = bands
            self.network = network
            self.ledger = ledger
        }

        /// Reads every key; a missing `network` key is damage, not "no network".
        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            schema = try c.decode(Int.self, forKey: .schema)
            width = try c.decode(Int.self, forKey: .width)
            height = try c.decode(Int.self, forKey: .height)
            channels = try c.decode(Int.self, forKey: .channels)
            diffusion = try c.decode([Double].self, forKey: .diffusion)
            decay = try c.decode([Double].self, forKey: .decay)
            amounts = try c.decode([[Int64]].self, forKey: .amounts)
            sources = try c.decode([SourceForm].self, forKey: .sources)
            bands = try c.decode([BandForm?].self, forKey: .bands)
            network = try c.decode(NetworkForm?.self, forKey: .network)
            ledger = try c.decode(NutrientLedger.self, forKey: .ledger)
        }

        /// Writes every key, `network` as null when there is none.
        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(schema, forKey: .schema)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(channels, forKey: .channels)
            try c.encode(diffusion, forKey: .diffusion)
            try c.encode(decay, forKey: .decay)
            try c.encode(amounts, forKey: .amounts)
            try c.encode(sources, forKey: .sources)
            try c.encode(bands, forKey: .bands)
            if let network {
                try c.encode(network, forKey: .network)
            } else {
                try c.encodeNil(forKey: .network)
            }
            try c.encode(ledger, forKey: .ledger)
        }
    }

    /// Only the schema, read before the rest so a newer layout is recognised.
    private struct SchemaProbe: Decodable {
        var schema: Int
    }

    /// This field as its stored form.
    private var storedForm: StoredForm {
        let n = cellCount
        var amounts: [[Int64]] = []
        amounts.reserveCapacity(channels)
        for k in 0..<channels {
            amounts.append(Array(amountQ[(k * n)..<((k + 1) * n)]))
        }
        var sourceForms: [SourceForm] = []
        sourceForms.reserveCapacity(sources.count)
        for s in sources {
            sourceForms.append(SourceForm(cell: s.cell, channel: s.channel, kind: s.kind, rate: s.rate, carry: s.carry))
        }
        var bandForms: [BandForm?] = []
        bandForms.reserveCapacity(channels)
        for band in bands {
            if let band {
                bandForms.append(BandForm(low: band.low, high: band.high, ramp: band.ramp))
            } else {
                bandForms.append(nil)
            }
        }
        var networkForm: NetworkForm?
        if let network {
            networkForm = NetworkForm(limit: network.limit, perFrame: network.perFrame, threshold: network.threshold,
                                      foodChannel: network.foodChannel, cost: network.cost, cells: network.cells,
                                      parents: network.parents)
        }
        return StoredForm(schema: Self.schema, width: width, height: height, channels: channels, diffusion: diffusion,
                          decay: decay, amounts: amounts, sources: sourceForms, bands: bandForms,
                          network: networkForm, ledger: ledger)
    }

    /// Builds a field from a stored form, re-running every rule of the initialisers and setters.
    private init(stored s: StoredForm) throws(NutrientError) {
        guard s.schema <= Self.schema else { throw .newerSchema(s.schema) }
        guard s.schema >= 1 else { throw .malformed("schema \(s.schema)") }
        do {
            try self.init(width: s.width, height: s.height, channels: s.channels, diffusion: s.diffusion,
                          decay: s.decay)
        } catch {
            throw .malformed("field: \(error)")
        }
        let n = cellCount

        // Amounts: one array per channel, each cell and each channel's total 0 … 2⁴⁰. Set directly, not through
        // add(_:channel:at:), so the stored ledger is not counted twice.
        guard s.amounts.count == channels else { throw .malformed("amounts: \(s.amounts.count) channels") }
        for k in 0..<channels {
            let row: [Int64] = s.amounts[k]
            guard row.count == n else { throw .malformed("amounts: channel \(k) has \(row.count) cells") }
            var sum: Int64 = 0
            for c in 0..<n {
                let a: Int64 = row[c]
                guard a >= 0, a <= Self.maxAmount else { throw .malformed("amounts: channel \(k) cell \(c) is \(a)") }
                sum += a  // At most 262,144 · 2⁴⁰ < 2⁵⁹: no overflow.
                amountQ[k * n + c] = a
            }
            guard sum <= Self.maxAmount else { throw .malformed("amounts: channel \(k) total \(sum)") }
            totalQ[k] = sum
        }

        // Sources and sinks, with their carries.
        for (i, form) in s.sources.enumerated() {
            do {
                let source = try NutrientSource(cell: form.cell, channel: form.channel, kind: form.kind,
                                                rate: form.rate, carry: form.carry)
                try addSource(source)
            } catch {
                throw .malformed("source \(i): \(error)")
            }
        }

        // Bands, one entry per channel.
        guard s.bands.count == channels else { throw .malformed("bands: \(s.bands.count) channels") }
        for k in 0..<channels {
            guard let form = s.bands[k] else { continue }
            do {
                try setBand(try ViabilityBand(low: form.low, high: form.high, ramp: form.ramp), channel: k)
            } catch {
                throw .malformed("band \(k): \(error)")
            }
        }

        // Network: settings through its initialiser; cells unique and in range; each parent −1 or an earlier network
        // cell that is a 4-neighbour.
        if let form = s.network {
            var grown: GrowthNetwork
            do {
                grown = try GrowthNetwork(limit: form.limit, perFrame: form.perFrame, threshold: form.threshold,
                                          foodChannel: form.foodChannel, cost: form.cost)
            } catch {
                throw .malformed("network: \(error)")
            }
            guard form.cells.count == form.parents.count else { throw .malformed("network: parents") }
            guard form.cells.count <= grown.limit else { throw .malformed("network: limit") }
            for i in 0..<form.cells.count {
                let cell: Int = form.cells[i]
                let parent: Int = form.parents[i]
                guard cell >= 0, cell < n else { throw .malformed("network: cell \(cell) out of range") }
                guard !grown.contains(cell) else { throw .malformed("network: cell \(cell) repeated") }
                if parent != -1 {
                    guard grown.contains(parent), Self.areNeighbours(cell, parent, width: width) else {
                        throw .malformed("network: parent \(parent) of cell \(cell)")
                    }
                }
                grown.append(cell, parent: parent)
            }
            do {
                try setNetwork(grown)
            } catch {
                throw .malformed("network: \(error)")
            }
        }

        // Ledger: one account per channel, non-negative counters whose net does not overflow, then the balance.
        guard s.ledger.accounts.count == channels else { throw .malformed("ledger") }
        for account in s.ledger.accounts {
            guard account.added >= 0, account.removed >= 0, account.faded >= 0, account.eaten >= 0 else {
                throw .malformed("ledger")
            }
            let (a, o1) = account.added.subtractingReportingOverflow(account.removed)
            let (b, o2) = a.subtractingReportingOverflow(account.faded)
            let (_, o3) = b.subtractingReportingOverflow(account.eaten)
            guard !o1, !o2, !o3 else { throw .malformed("ledger") }
        }
        ledger = s.ledger
        guard isBalanced else { throw .malformed("ledger") }
    }

    /// Whether two in-range cells of a grid `width` wide share an edge (walled: no wrap between rows).
    private static func areNeighbours(_ a: Int, _ b: Int, width: Int) -> Bool {
        let ax = a % width, ay = a / width, bx = b % width, by = b / width
        return (ay == by && abs(ax - bx) == 1) || (ax == bx && abs(ay - by) == 1)
    }

    // MARK: Codable

    /// Writes the schema-1 stored form.
    public func encode(to encoder: any Encoder) throws {
        try storedForm.encode(to: encoder)
    }

    /// Reads a stored field and checks it with every rule of the initialisers and setters; a newer schema or a broken
    /// rule is a `DecodingError.dataCorrupted` whose description is the reason code.
    public init(from decoder: any Decoder) throws {
        let stored = try StoredForm(from: decoder)
        do {
            try self.init(stored: stored)
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// The stored form as JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(storedForm)
        } catch {
            // Every stored value is an integer, a finite double (the initialisers refuse non-finite rates, bands and
            // carries, and a step keeps carries in 0 ..< 1), a kind string or null, so JSONEncoder cannot fail here.
            preconditionFailure("NutrientField.encoded: \(error)")
        }
    }

    /// Reads a field from its stored form and re-runs every rule.
    ///
    /// - Throws: `.newerSchema(s)` for a schema above ``schema``; `.malformed(description)` for unreadable JSON,
    ///   missing or mistyped keys, a schema below 1, any value that breaks a rule of the initialisers and setters, or a
    ///   ledger that does not balance.
    public static func decode(_ data: Data) throws(NutrientError) -> NutrientField {
        let decoder = JSONDecoder()
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        let stored: StoredForm
        do {
            stored = try decoder.decode(StoredForm.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        return try NutrientField(stored: stored)
    }
}
