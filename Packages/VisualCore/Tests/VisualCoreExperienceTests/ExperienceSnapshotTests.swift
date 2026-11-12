// ExperienceSnapshotTests — feature 188 T-U02-019 (FR-U02-040, FR-U02-043, FR-U02-046, FR-U02-047, FR-U02-085;
// data-model section 4): the encoded form of a snapshot, its validation order, storage through a document store
// and 1,000 generated inputs that each give a typed error or a valid snapshot.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct ExperienceSnapshotTests {
    private static let payloadText = #"{"energy":3,"path":"a/b"}"#
    private static let digestHex = String(repeating: "ab", count: 32)

    private func sampleID() throws -> ExperienceID { try ExperienceID("a99.contract-sample") }

    private func sampleDigest() throws -> StateDigest { try #require(StateDigest(hex: Self.digestHex)) }

    private func make(schema: Int = 2, seed: UInt64 = 7, step: Int = 240,
                      payload: String = ExperienceSnapshotTests.payloadText) throws -> ExperienceSnapshot {
        try ExperienceSnapshot(experience: sampleID(), schemaVersion: schema, seed: seed, stepIndex: step,
                               digest: sampleDigest(), payload: Data(payload.utf8))
    }

    /// SHA-256 of the text as lower-case hexadecimal digits, computed independently of the package.
    private func sha256(_ text: String) -> String {
        StableHash.sha256Hex(Array(text.utf8))
    }

    /// The encoded form of a valid snapshot after `change` edited its fields.
    private func envelope(_ change: (inout [String: Any]) -> Void) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: try make().encoded())
        var fields = try #require(object as? [String: Any])
        change(&fields)
        return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }

    /// The error `init(data:)` answers, or nil when the data is a valid snapshot.
    private func refusal(_ data: Data) -> SnapshotError? {
        do {
            _ = try ExperienceSnapshot(data: data)
            return nil
        } catch {
            return error
        }
    }

    private func isCorrupt(_ data: Data) -> Bool {
        if case .corrupt(let reason)? = refusal(data) { return !reason.isEmpty }
        return false
    }

    private func refusal(changing change: (inout [String: Any]) -> Void) throws -> SnapshotError? {
        refusal(try envelope(change))
    }

    private func isCorrupt(changing change: (inout [String: Any]) -> Void) throws -> Bool {
        isCorrupt(try envelope(change))
    }

    // MARK: encoded form

    @Test func encodedFormHasTheEightKeysInSortedOrder() throws {
        let snapshot = try make(seed: UInt64.max)
        let text = String(decoding: try snapshot.encoded(), as: UTF8.self)
        let expected = #"{"checksum":""# + sha256(Self.payloadText) + #"","digest":""# + Self.digestHex
            + #"","experience":"a99.contract-sample","format":1,"payload":"{\"energy\":3,\"path\":\"a/b\"}","#
            + #""schema":2,"seed":"18446744073709551615","step":240}"#
        #expect(text == expected)
        #expect(!text.contains(" ") && !text.contains("\n") && !text.contains("\t"))

        let object = try JSONSerialization.jsonObject(with: try snapshot.encoded())
        let fields = try #require(object as? [String: Any])
        let keys = ["checksum", "digest", "experience", "format", "payload", "schema", "seed", "step"]
        #expect(fields.keys.sorted() == keys)
        #expect(fields["seed"] as? String == "18446744073709551615")
        #expect(String(decoding: try make(seed: 0).encoded(), as: UTF8.self).contains(#""seed":"0","#))
    }

    @Test func propertiesAndChecksum() throws {
        let snapshot = try make(schema: 2, seed: 99, step: 12)
        #expect(ExperienceSnapshot.format == 1)
        #expect(ExperienceSnapshot.maxBytes == 1_048_576)
        let id = try sampleID()
        #expect(snapshot.experience == id)
        #expect(snapshot.schemaVersion == 2)
        #expect(snapshot.seed == 99)
        #expect(snapshot.stepIndex == 12)
        #expect(snapshot.digest.hex == Self.digestHex)
        #expect(snapshot.payload == Self.payloadText)
        #expect(snapshot.checksum == sha256(Self.payloadText))
        #expect(try make(payload: "{}").checksum == "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a")
    }

    @Test func encodingIsDeterministicAndRoundTrips() throws {
        for seed in [0, 1, 7, UInt64.max - 1, UInt64.max] {
            let snapshot = try make(seed: seed, payload: #"{"text":"line\nbreak \"q\" / é","values":[1,2.5,-3e2]}"#)
            let first = try snapshot.encoded()
            #expect(try snapshot.encoded() == first)
            let decoded = try ExperienceSnapshot(data: first)
            #expect(decoded == snapshot)
            #expect(try decoded.encoded() == first)
        }
        #expect(try make() == make())
        #expect(try make(seed: 1) != make(seed: 2))
    }

    // MARK: init(data:)

    @Test func dataAboveTheLimitIsTooLarge() throws {
        let tooBig = Data(repeating: UInt8(ascii: "x"), count: ExperienceSnapshot.maxBytes + 1)
        #expect(refusal(tooBig) == .tooLarge(bytes: 1_048_577))
        // At the limit the size is accepted and the content is looked at.
        #expect(isCorrupt(Data(repeating: UInt8(ascii: "x"), count: ExperienceSnapshot.maxBytes)))
    }

    @Test func textThatIsNotASnapshotObjectIsCorrupt() throws {
        for text in ["", "not json", "{", "[1,2]", "3", "\"text\"", "null", "{}", #"{"format":1}"#] {
            #expect(isCorrupt(Data(text.utf8)), "\(text)")
        }
        #expect(isCorrupt(Data([0xFF, 0xFE, 0x00])))
    }

    @Test func missingMistypedAndExtraKeysAreCorrupt() throws {
        let keys = ["checksum", "digest", "experience", "format", "payload", "schema", "seed", "step"]
        for key in keys {
            let data = try envelope { $0[key] = nil }
            guard case .corrupt(let reason)? = refusal(data) else {
                Issue.record("a missing \(key) is not reported as corrupt")
                continue
            }
            #expect(reason.contains(key))
        }
        let mistyped: [(String, Any)] = [
            ("checksum", 5), ("digest", NSNull()), ("experience", [1]), ("format", "1"),
            ("payload", ["energy": 3]), ("schema", true), ("schema", "2"), ("seed", 7), ("step", "240"),
        ]
        for (key, value) in mistyped {
            let data = try envelope { $0[key] = value }
            guard case .corrupt(let reason)? = refusal(data) else {
                Issue.record("a mistyped \(key) is not reported as corrupt")
                continue
            }
            #expect(reason.contains(key))
        }
        #expect(try isCorrupt(changing: { $0["format"] = 1.5 }))
        #expect(try isCorrupt(changing: { $0["step"] = 240.5 }))
        let extra = try envelope { $0["extra"] = 1 }
        guard case .corrupt(let reason)? = refusal(extra) else {
            Issue.record("an unknown key is not reported as corrupt")
            return
        }
        #expect(reason.contains("extra"))
    }

    @Test func malformedIdSeedDigestAndNumbersAreCorrupt() throws {
        for id in ["", "A99.contract-sample", "a99", "a99.Contract", "a00.x", "a99.x.y", "a99.-x"] {
            #expect(try isCorrupt(changing: { $0["experience"] = id }), "id \(id)")
        }
        for seed in ["", "-1", "+5", "1.5", "07", " 7", "0x10", "seven", "18446744073709551616"] {
            #expect(try isCorrupt(changing: { $0["seed"] = seed }), "seed \(seed)")
        }
        let digests = ["", String(repeating: "AB", count: 32), String(repeating: "ab", count: 31),
                       String(repeating: "ab", count: 33), String(repeating: "zz", count: 32)]
        for digest in digests {
            #expect(try isCorrupt(changing: { $0["digest"] = digest }), "digest \(digest)")
        }
        #expect(try isCorrupt(changing: { $0["schema"] = -1 }))
        #expect(try isCorrupt(changing: { $0["step"] = -1 }))
        #expect(try refusal(changing: { $0["schema"] = 0; $0["step"] = 0 }) == nil)
    }

    @Test func payloadThatIsNotAJSONObjectIsCorrupt() throws {
        for payload in ["", "[1]", "3", "\"text\"", "null", "{", #"{"a":}"#] {
            let data = try envelope {
                $0["payload"] = payload
                $0["checksum"] = sha256(payload)
            }
            #expect(isCorrupt(data), "payload \(payload)")
        }
    }

    @Test func anotherFormatIsUnknown() throws {
        #expect(try refusal(changing: { $0["format"] = 2 }) == .unknownFormat(2))
        #expect(try refusal(changing: { $0["format"] = 0 }) == .unknownFormat(0))
        #expect(try refusal(changing: { $0["format"] = -1 }) == .unknownFormat(-1))
        // The format is checked before the forms of the other fields and before the checksum.
        let data = try envelope {
            $0["format"] = 2
            $0["experience"] = "nothing"
            $0["checksum"] = "0"
        }
        #expect(refusal(data) == .unknownFormat(2))
    }

    @Test func changedPayloadOrChecksumIsAChecksumMismatch() throws {
        #expect(try refusal(changing: { $0["payload"] = #"{"energy":4,"path":"a/b"}"# }) == .checksumMismatch)
        #expect(try refusal(changing: { $0["payload"] = Self.payloadText + " " }) == .checksumMismatch)
        #expect(try refusal(changing: { $0["checksum"] = String(repeating: "0", count: 64) }) == .checksumMismatch)
        #expect(try refusal(changing: { $0["checksum"] = "" }) == .checksumMismatch)
        #expect(try refusal(changing: { $0["checksum"] = sha256(Self.payloadText).uppercased() }) == .checksumMismatch)
        // The checksum is checked before the payload is parsed, and after the forms of the other fields.
        #expect(try refusal(changing: { $0["payload"] = "[1]" }) == .checksumMismatch)
        let data = try envelope {
            $0["payload"] = "{}"
            $0["seed"] = "-1"
        }
        #expect(isCorrupt(data))
    }

    // MARK: init(experience:…payload:)

    @Test func initRefusesAPayloadThatIsNotAUTF8JSONObject() throws {
        let id = try sampleID(), digest = try sampleDigest()
        func refused(_ payload: Data, schema: Int = 1, step: Int = 0) -> SnapshotError? {
            do {
                _ = try ExperienceSnapshot(experience: id, schemaVersion: schema, seed: 1, stepIndex: step,
                                           digest: digest, payload: payload)
                return nil
            } catch {
                return error
            }
        }
        let bad: [Data] = [Data(), Data([0xFF, 0xFE]), Data([0x7B, 0x22, 0xC3, 0x28, 0x22, 0x3A, 0x31, 0x7D]),
                           Data("[1]".utf8), Data("3".utf8), Data("\"text\"".utf8), Data("{".utf8), Data("null".utf8)]
        for payload in bad {
            guard case .corrupt? = refused(payload) else {
                Issue.record("the payload \(Array(payload)) was not refused as corrupt")
                continue
            }
        }
        guard case .corrupt? = refused(Data("{}".utf8), schema: -1) else {
            Issue.record("a negative schema version was not refused")
            return
        }
        guard case .corrupt? = refused(Data("{}".utf8), step: -1) else {
            Issue.record("a negative step index was not refused")
            return
        }
        #expect(refused(Data("{}".utf8), schema: 0) == nil)
        #expect(refused(Data(#" { "a" : [1, 2] } "#.utf8)) == nil)
    }

    @Test func initRefusesAPayloadThatMakesTheSnapshotTooLarge() throws {
        let big = #"{"a":""# + String(repeating: "x", count: ExperienceSnapshot.maxBytes) + #""}"#
        do {
            _ = try make(payload: big)
            Issue.record("a payload above the limit was accepted")
        } catch SnapshotError.tooLarge(let bytes) {
            #expect(bytes > ExperienceSnapshot.maxBytes)
        } catch {
            Issue.record("expected tooLarge, got \(error)")
        }
        // A large payload below the limit is accepted and round-trips.
        let fits = #"{"a":""# + String(repeating: "x", count: 900_000) + #""}"#
        let snapshot = try make(payload: fits)
        let data = try snapshot.encoded()
        #expect(data.count <= ExperienceSnapshot.maxBytes)
        #expect(try ExperienceSnapshot(data: data) == snapshot)
    }

    // MARK: Codable and storage

    @Test func codableWritesTheSameFieldsAndValidates() throws {
        let snapshot = try make(seed: UInt64.max)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        #expect(try encoder.encode(snapshot) == snapshot.encoded())
        #expect(try JSONDecoder().decode(ExperienceSnapshot.self, from: snapshot.encoded()) == snapshot)

        let cases: [(Data, String)] = [
            (try envelope { $0["format"] = 2 }, "snapshot.unknown-format"),
            (try envelope { $0["payload"] = "{}" }, "snapshot.checksum-mismatch"),
            (try envelope { $0["seed"] = "-1" }, "snapshot.corrupt"),
        ]
        for (data, code) in cases {
            do {
                _ = try JSONDecoder().decode(ExperienceSnapshot.self, from: data)
                Issue.record("a snapshot with \(code) was decoded")
            } catch DecodingError.dataCorrupted(let context) {
                #expect(context.debugDescription.contains(code))
            } catch {
                Issue.record("expected dataCorrupted with \(code), got \(error)")
            }
        }
        let extra = try envelope { $0["extra"] = 1 }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ExperienceSnapshot.self, from: extra)
        }
    }

    @Test func documentStoreKeepsASnapshotAndReportsAChangedPayload() throws {
        let folder = TemporaryFolder(name: "ExperienceSnapshotTests-" + UUID().uuidString)
        defer { folder.removeAll() }
        let id = try sampleID()
        let store = DocumentStore<ExperienceSnapshot>(directory: folder.url, kind: id.storageNamespace,
                                                      migrations: MigrationChain(currentVersion: 1),
                                                      maxBytes: 2 * 1024 * 1024)
        let snapshot = try make(seed: UInt64.max)
        try store.save(snapshot, id: "slot-1")
        let loaded = try store.load(id: "slot-1")
        #expect(loaded.value == snapshot)
        #expect(loaded.migratedFrom == nil)
        #expect(try loaded.value.encoded() == snapshot.encoded())

        let file = folder.url.appendingPathComponent("slot-1.json")
        let text = try String(contentsOf: file, encoding: .utf8)
        let changed = text.replacingOccurrences(of: "energy", with: "enerqy")
        #expect(changed != text)
        try Data(changed.utf8).write(to: file)
        do {
            _ = try store.load(id: "slot-1")
            Issue.record("a file with a changed payload was loaded")
        } catch {
            guard case .corrupt(let name, let reason) = error else {
                Issue.record("expected a corrupt file, got \(error)")
                return
            }
            #expect(name == "slot-1.json")
            #expect(reason.contains("snapshot.checksum-mismatch"))
        }
        let report = store.load()
        #expect(report.items.isEmpty)
        #expect(report.problems.count == 1)
    }

    // MARK: generated inputs (FR-U02-085)

    @Test func aThousandGeneratedInputsGiveATypedErrorOrASnapshot() throws {
        var random = SplitMix64(seed: 0x5EED_0188_0019)
        func below(_ bound: Int) -> Int { bound > 0 ? Int(random.next() % UInt64(bound)) : 0 }
        let payloads = ["{}", Self.payloadText, #"{"grid":[[0,1],[1,0]],"name":"é ü","nested":{"a":null,"b":true}}"#]
        var valid = 0, refused = 0, shortenedAccepted = 0

        func feed(_ data: Data) -> Bool {
            let accepted = refusal(data) == nil
            if accepted { valid += 1 } else { refused += 1 }
            // The Codable door gets the same input; it may throw but must return.
            _ = try? JSONDecoder().decode(ExperienceSnapshot.self, from: data)
            return accepted
        }

        for _ in 0..<400 {
            var bytes: [UInt8] = []
            for _ in 0..<below(201) { bytes.append(UInt8(truncatingIfNeeded: random.next())) }
            _ = feed(Data(bytes))
        }
        for index in 0..<600 {
            let snapshot = try make(schema: below(4), seed: random.next(), step: below(100_000),
                                    payload: payloads[index % payloads.count])
            var bytes = Array(try snapshot.encoded())
            if index < 300 {
                bytes.removeLast(min(bytes.count, 1 + below(bytes.count)))
                if feed(Data(bytes)) { shortenedAccepted += 1 }
            } else {
                let at = below(bytes.count)
                guard bytes.indices.contains(at) else { continue }
                let old = bytes[at]
                var new = UInt8(truncatingIfNeeded: random.next())
                if new == old { new = old &+ 1 }
                bytes[at] = new
                _ = feed(Data(bytes))
            }
        }
        #expect(valid + refused == 1_000)
        #expect(refused >= 700)
        #expect(shortenedAccepted == 0)
    }
}
