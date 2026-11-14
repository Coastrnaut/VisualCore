// DomainTests — feature 012 T-A01-108 (FR-A01-101, FR-A01-103–FR-A01-106; SC-A01-102).
import Foundation
import Testing
import VisualCoreParameters
import VisualCoreSimulation
@testable import GenerativeArtStudioCore

@Test func catalogHasFourDistinctFamiliesWithPresets() throws {
    #expect(FamilyCatalog.all.map(\.id) == SceneFamilyID.allCases)
    for f in FamilyCatalog.all {
        #expect(!f.title.isEmpty && !f.summary.isEmpty && !f.accessibilityDescription.isEmpty)
        #expect(f.presets.count >= 1)
        #expect(FamilyCatalog.palette(f.defaultPaletteID) != nil)
        for preset in f.presets {
            #expect(FamilyCatalog.palette(preset.paletteID) != nil, "\(preset.id) palette")
            let r = try f.schema.resolve(preset.values)
            #expect(r.warnings.isEmpty, "preset \(preset.id) values are in range and known: \(r.warnings)")
        }
    }
    #expect(Set(FamilyCatalog.all.flatMap { $0.presets.map(\.id) }).count == FamilyCatalog.all.flatMap(\.presets).count)
}

/// Deterministic generator of varied documents (SC-A01-102: ≥ 50, including edge seeds).
private func generatedDocuments(count: Int = 60) -> [ArtDocument] {
    var rng = SeededRandom(seed: 0xA01)
    var docs: [ArtDocument] = []
    for i in 0..<count {
        let family = FamilyCatalog.all[i % 4]
        let seed: UInt64 = i == 0 ? 0 : (i == 1 ? .max : rng.next())
        var values: [String: Double] = [:]
        for d in family.schema.definitions where rng.double() < 0.8 {
            values[d.name] = d.value(normalized: rng.double())
        }
        let palette = FamilyCatalog.palettes[Int(rng.next() % UInt64(FamilyCatalog.palettes.count))].id
        docs.append(ArtDocument(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!, family: family.id,
                                seed: seed, paletteID: palette, parameters: values, previewTime: rng.double() * 120))
    }
    return docs
}

@Test func roundTripsAreExactWithStableHash() throws {
    let docs = generatedDocuments()
    #expect(docs.count >= 50)
    #expect(docs.contains { $0.seed == 0 } && docs.contains { $0.seed == .max })
    for doc in docs {
        let valid = try doc.validated().document
        let data = try valid.canonicalJSON()
        let back = try ArtDocument.decode(data)
        #expect(back.document == valid)
        #expect(back.warnings.isEmpty)
        #expect(back.document.hash == valid.hash)
        #expect(try back.document.canonicalJSON() == data, "canonical encoding is byte-stable")
    }
    let maxSeed = try generatedDocuments()[1].canonicalJSON()
    #expect(String(decoding: maxSeed, as: UTF8.self).contains("\"seed\":\"18446744073709551615\""))
}

@Test func validationOutcomes() throws {
    var d = ArtDocument(family: .gradientNoise, seed: 1, paletteID: "ocean", parameters: ["scale": 999, "bogus": 1], previewTime: 500)
    let (valid, warnings) = try d.validated()
    #expect(valid.parameters["scale"] == 16)
    #expect(valid.parameters.keys.sorted() == FamilyCatalog.family(.gradientNoise).schema.definitions.map(\.name).sorted())
    #expect(valid.previewTime == 120)
    #expect(warnings.contains("bogus: unknown parameter dropped"))
    #expect(warnings.contains { $0.hasPrefix("scale: 999.0 clamped") })
    #expect(warnings.contains("previewTime 500.0 clamped to 120.0"))

    d.paletteID = "nope"
    let fallback = try d.validated()
    #expect(fallback.document.paletteID == "sunset")
    #expect(fallback.warnings.contains("palette 'nope' unknown; using 'sunset'"))

    d.parameters = ["warp": .nan]
    #expect(throws: DocumentError.nonFinite("warp")) { try d.validated() }
    d.parameters = [:]; d.previewTime = .infinity
    #expect(throws: DocumentError.nonFinite("previewTime")) { try d.validated() }
    d.previewTime = 0; d.familyID = "watercolor"
    #expect(throws: DocumentError.unknownFamily("watercolor")) { try d.validated() }
    d.familyID = "particles"; d.schemaVersion = 2
    #expect(throws: DocumentError.unsupportedVersion(2)) { try d.validated() }
    d.schemaVersion = 0
    #expect(throws: DocumentError.unsupportedVersion(0)) { try d.validated() }
}

@Test func decodeRejectsCorruptData() {
    #expect(throws: DocumentError.self) { try ArtDocument.decode(Data("{".utf8)) }
    let negativeSeed = #"{"familyID":"particles","id":"00000000-0000-0000-0000-000000000001","paletteID":"ember","parameters":{},"previewTime":0,"schemaVersion":1,"seed":"-4"}"#
    #expect(throws: DocumentError.self) { try ArtDocument.decode(Data(negativeSeed.utf8)) }
    let future = #"{"familyID":"particles","id":"00000000-0000-0000-0000-000000000001","paletteID":"ember","parameters":{},"previewTime":0,"schemaVersion":7,"seed":"4"}"#
    #expect(throws: DocumentError.unsupportedVersion(7)) { try ArtDocument.decode(Data(future.utf8)) }
}

@Test func hashTracksEveryField() throws {
    let base = try ArtDocument(family: .geometricTiling, seed: 9, paletteID: "neon", parameters: [:]).validated().document
    var a = base; a.seed = 10
    var b = base; b.paletteID = "mono"
    var c = base; c.parameters["cells"] = 7
    var e = base; e.familyID = SceneFamilyID.gradientNoise.rawValue
    #expect(Set([base.hash, a.hash, b.hash, c.hash, e.hash]).count == 5)
    var sameContent = base; sameContent.id = UUID(); sameContent.previewTime = 3
    #expect(sameContent.hash == base.hash, "id and preview time do not change the visual identity")
}

@Test func seedOffsetsAreDeterministicAndInRange() {
    #expect(SeedOffsets.of(42) == SeedOffsets.of(42))
    #expect(SeedOffsets.of(42) != SeedOffsets.of(43))
    for seed: UInt64 in [0, 1, .max] {
        let o = SeedOffsets.of(seed)
        for i in 0..<4 { #expect((0..<1).contains(o[i])) }
    }
}

@Test func particleReplayIsDeterministicBoundedAndSeedSensitive() throws {
    let doc = try ArtDocument.from(FamilyCatalog.family(.particles).defaultPreset, family: .particles).validated().document
    let a = ParticleReplay.instances(for: doc, at: 2), b = ParticleReplay.instances(for: doc, at: 2)
    #expect(a == b)
    #expect(a.count > 100)
    var other = doc; other.seed = 6
    #expect(ParticleReplay.instances(for: other, at: 2) != a)
    #expect(ParticleReplay.instances(for: doc, at: 0).isEmpty)
    // The 120 s cap, by arithmetic on the shared step count (owner short-test rule of 2026-11-13: a two-minute replay
    // twice took 12 s under parallel load); the replay itself is exercised at short times.
    #expect(ParticleReplay.stepCount(at: 10_000) == ParticleReplay.stepCount(at: 120), "replay time is capped at 120 s")
    #expect(ParticleReplay.stepCount(at: 120) == 7_200)
    #expect(ParticleReplay.stepCount(at: -5) == 0 && ParticleReplay.stepCount(at: .nan) == 0)
    #expect(ParticleReplay.instances(for: doc, at: 4).count <= ParticleReplay.capacity)
    #expect(a.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite })
}

@Test func replayCursorMatchesFullReplay() throws {
    let doc = try ArtDocument.from(FamilyCatalog.family(.particles).presets[1], family: .particles).validated().document
    var cursor = ParticleReplayCursor(document: doc)
    for t in [0.5, 1.0, 3.25, 2.0, 4.0] {   // forward, forward, forward, backward (rebuild), forward again (the cap is
                                            // the shared `stepCount`, checked by arithmetic above)
        #expect(cursor.instances(at: t) == ParticleReplay.instances(for: doc, at: t), "t = \(t)")
    }
}

@Test func migrationHookIsAppliedAndIdentityForVersion1() throws {
    let doc = try ArtDocument(family: .geometricTiling, seed: 77, paletteID: "neon", parameters: ["cells": 9]).validated().document
    #expect(ArtDocument.migrate(doc) == doc, "schema 1 is current: migration is the identity")
    #expect(try ArtDocument.decode(doc.canonicalJSON()).document == doc, "decode runs migrate then validate")
    // A stored version-1 document written by hand (keys in a different order) decodes to the same document.
    let handWritten = #"{"seed":"77","schemaVersion":1,"previewTime":0,"parameters":{"cells":9},"paletteID":"neon","id":"\#(doc.id.uuidString)","familyID":"geometric-tiling"}"#
    #expect(try ArtDocument.decode(Data(handWritten.utf8)).document == doc)
}
