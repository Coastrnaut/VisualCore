// ContentPackTests — feature 127 (A17-P04) T-A17-404 (FR-A17-407; SC-A17-404; clarification Q4). The content pack,
// host-free and short: the bundled pack (kind "a17.content-pack", schema 2) loads and validates; the digest is equal
// twice and after encode → decode; a bare A17-P01 region (pack schema 1) migrates by wrapping; damaged JSON, a wrong
// kind, schema 3, schema 0 and 262,145 bytes are refused with damaged, damaged, newer-version, damaged and too-large.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

/// The refusal reason of decoding `data` as a pack, or nil when it decodes.
private func packRefusalReason(_ data: Data) -> ContentRefusal.Reason? {
    if case .failure(let refusal) = AnatomyContentPack.decode(data) { return refusal.reason }
    return nil
}

/// The pack of the bundled knee as a JSON object changed by `change`, written back with sorted keys.
private func packMutatedJSON(_ change: (inout [String: Any]) -> Void) throws -> Data {
    let data = AnatomyContentPack.encode(try AnatomyContent.bundledRightKnee())
    var object = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    change(&object)
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

@Suite struct ContentPackTests {
    @Test func theBundledPackLoadsAndValidates() throws {
        let region = try AnatomyContent.bundledRightKnee()
        #expect(AnatomyContent.validate(region) == nil)
        #expect(region.contentVersion == 2)
        #expect(AnatomyContentPack.kind == "a17.content-pack")
        #expect(AnatomyContentPack.schemaVersion == 2)
        let data = AnatomyContentPack.encode(region)
        let object = try #require((try JSONSerialization.jsonObject(with: data)) as? [String: Any])
        #expect(object["kind"] as? String == "a17.content-pack")
        #expect(object["schemaVersion"] as? Int == 2)
        #expect(object["savedAt"] as? String == "2026-11-16T00:00:00Z")
    }

    @Test func theDigestIsStable() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let digest = AnatomyContentPack.digest(region)
        #expect(digest.count == 64)
        #expect(AnatomyContentPack.digest(region) == digest)
        let decoded = try AnatomyContentPack.decode(AnatomyContentPack.encode(region)).get()
        #expect(decoded == region)
        #expect(AnatomyContentPack.digest(decoded) == digest)
        #expect(AnatomyContentPack.encode(decoded) == AnatomyContentPack.encode(region))
    }

    @Test func aBareRegionMigratesByWrapping() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let bare = AnatomyContent.encoded(region)
        let migrated = AnatomyContentPack.decode(bare)
        #expect(migrated == .success(region))
    }

    @Test func damagedJSONAndAWrongKindAreDamaged() throws {
        #expect(packRefusalReason(Data("{".utf8)) == .damaged)
        #expect(packRefusalReason(Data("[1]".utf8)) == .damaged)
        #expect(packRefusalReason(Data("{\"kind\": \"a17.content-pack\"}".utf8)) == .damaged)
        let wrongKind = try packMutatedJSON { $0["kind"] = "a17.view" }
        #expect(packRefusalReason(wrongKind) == .damaged)
        let noPayload = try packMutatedJSON { $0.removeValue(forKey: "payload") }
        #expect(packRefusalReason(noPayload) == .damaged)
        let schemaZero = try packMutatedJSON { $0["schemaVersion"] = 0 }
        #expect(packRefusalReason(schemaZero) == .damaged)
    }

    @Test func schemaThreeIsANewerVersion() throws {
        let newer = try packMutatedJSON { $0["schemaVersion"] = 3 }
        #expect(packRefusalReason(newer) == .newerVersion)
        let unchanged = try packMutatedJSON { _ in }
        #expect(packRefusalReason(unchanged) == nil)
    }

    @Test func oneByteOverTheLimitIsTooLarge() throws {
        #expect(AnatomyContentPack.maxBytes == 262_144)
        var data = AnatomyContentPack.encode(try AnatomyContent.bundledRightKnee())
        data.append(Data(repeating: 0x20, count: AnatomyContentPack.maxBytes + 1 - data.count))
        #expect(data.count == 262_145)
        #expect(packRefusalReason(data) == .tooLarge)
    }

    @Test func anInvalidPayloadIsRefusedByValidation() throws {
        let invalid = try packMutatedJSON { object in
            var payload = object["payload"] as? [String: Any] ?? [:]
            var manifest = payload["manifest"] as? [String: Any] ?? [:]
            manifest["textLicense"] = "proprietary"
            payload["manifest"] = manifest
            object["payload"] = payload
        }
        #expect(packRefusalReason(invalid) == .badLicense)
    }
}
