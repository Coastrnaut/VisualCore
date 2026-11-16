// ContentValidationTests — feature 124 (A17-P01) T-A17-108 (SC-A17-102; FR-A17-103, FR-A17-107). Every label maps to
// something real, host-free and short: each refusal reason reachable through `validate` is produced by a mutated copy
// of the bundled knee, and the sentence names the offending id or word; a description with a clinical word, more than
// three sentences or more than 400 characters is refused; neighbours must be symmetric; every bundled label resolves
// to a structure and its first declared mesh; every refusal reason (decode ones included) is produced by some case.
import Foundation
import Testing
import VisualCoreMath
@testable import InteractiveAnatomyCore

/// One mutation of the bundled region and the refusal it must produce.
private struct ValidationCase {
    /// What the case changes.
    let name: String
    /// The expected refusal reason.
    let reason: ContentRefusal.Reason
    /// The sentence must contain one of these (case-insensitive); empty skips the check.
    let naming: [String]
    /// The change applied to a copy of the bundled region.
    let mutate: (inout AnatomyRegion) -> Void
}

/// Applies `change` to the structure `id` of `region`.
private func changeStructure(_ region: inout AnatomyRegion, _ id: String,
                             _ change: (inout AnatomicalStructure) -> Void) {
    guard let index = region.structures.firstIndex(where: { $0.id == id }) else { return }
    change(&region.structures[index])
}

/// The first non-root structure other than `excluded` with fewer than three meshes.
private func partWithMeshRoom(_ region: AnatomyRegion, excluding excluded: String) -> String {
    for structure in region.structures where structure.parent != nil && structure.id != excluded {
        if structure.meshIDs.count < 3 { return structure.id }
    }
    return "knee.patella"
}

/// Adds every structure-level case to `list`.
private func appendStructureCases(_ list: inout [ValidationCase], _ base: AnatomyRegion) {
    let femurMesh = base.structure("knee.femur")?.meshIDs.first ?? "mesh.femur"
    let roomy = partWithMeshRoom(base, excluding: "knee.femur")
    let firstMesh = base.meshes.first ?? ProceduralMeshDeclaration(id: femurMesh, kind: .revolution)
    list.append(ValidationCase(name: "mesh declared twice", reason: .duplicateID, naming: [firstMesh.id]) { r in
        r.meshes.append(ProceduralMeshDeclaration(id: firstMesh.id, kind: firstMesh.kind))
    })
    list.append(ValidationCase(name: "mesh owned twice", reason: .duplicateID,
                               naming: [femurMesh, roomy, "knee.femur"]) { r in
        changeStructure(&r, roomy) { $0.meshIDs.append(femurMesh) }
    })
    list.append(ValidationCase(name: "blank description", reason: .emptyText, naming: ["knee.patella"]) { r in
        changeStructure(&r, "knee.patella") { $0.description = "   " }
    })
    list.append(ValidationCase(name: "empty English name", reason: .emptyText, naming: ["knee.fibula"]) { r in
        changeStructure(&r, "knee.fibula") { $0.englishName = "" }
    })
    list.append(ValidationCase(name: "blank standard name", reason: .emptyText, naming: ["knee.tibia"]) { r in
        changeStructure(&r, "knee.tibia") { $0.standardName = " \n " }
    })
    let long = "The femur" + String(repeating: " is long", count: 60) + "."
    list.append(ValidationCase(name: "description over 400", reason: .emptyText, naming: ["knee.femur"]) { r in
        changeStructure(&r, "knee.femur") { $0.description = long }
    })
    let four = "The bone is long. It is hard. It is pale. It lies above the knee."
    list.append(ValidationCase(name: "four sentences", reason: .emptyText, naming: ["knee.femur"]) { r in
        changeStructure(&r, "knee.femur") { $0.description = four }
    })
    list.append(ValidationCase(name: "clinical word", reason: .clinicalText, naming: ["treatment"]) { r in
        changeStructure(&r, "knee.acl") { $0.description = "This band can need Treatment after a fall." }
    })
    list.append(ValidationCase(name: "clinical phrase", reason: .clinicalText, naming: ["medical advice"]) { r in
        changeStructure(&r, "knee.pcl") { $0.description = "This band is not medical advice." }
    })
    list.append(ValidationCase(name: "no sources", reason: .unsourced, naming: ["knee.acl"]) { r in
        changeStructure(&r, "knee.acl") { $0.sourceRefs = [] }
    })
    list.append(ValidationCase(name: "unknown source", reason: .missingReference,
                               naming: ["no-such-citation"]) { r in
        changeStructure(&r, "knee.mcl") { $0.sourceRefs = ["no-such-citation"] }
    })
}

/// Adds every reference, hierarchy and region-level case to `list`.
private func appendReferenceCases(_ list: inout [ValidationCase], _ base: AnatomyRegion) {
    let roomy = partWithMeshRoom(base, excluding: "")
    list.append(ValidationCase(name: "unknown parent", reason: .missingReference, naming: ["knee.nothing"]) { r in
        changeStructure(&r, "knee.patella") { $0.parent = "knee.nothing" }
    })
    list.append(ValidationCase(name: "unknown neighbour", reason: .missingReference, naming: ["knee.ghost"]) { r in
        changeStructure(&r, "knee.femur") { $0.neighbours.append("knee.ghost") }
    })
    list.append(ValidationCase(name: "asymmetric neighbour", reason: .missingReference,
                               naming: ["knee.patella"]) { r in
        changeStructure(&r, "knee.patella") { $0.neighbours.removeAll { $0 == "knee.femur" } }
    })
    list.append(ValidationCase(name: "self neighbour", reason: .missingReference, naming: ["knee.femur"]) { r in
        changeStructure(&r, "knee.femur") { $0.neighbours.append("knee.femur") }
    })
    list.append(ValidationCase(name: "unknown mesh", reason: .missingReference, naming: ["mesh.ghost"]) { r in
        changeStructure(&r, roomy) { $0.meshIDs.append("mesh.ghost") }
    })
    list.append(ValidationCase(name: "orphan mesh", reason: .missingReference, naming: ["mesh.orphan.part"]) { r in
        r.meshes.append(ProceduralMeshDeclaration(id: "mesh.orphan.part", kind: .sphere))
    })
    list.append(ValidationCase(name: "part without layer", reason: .missingReference, naming: ["knee.mcl"]) { r in
        changeStructure(&r, "knee.mcl") { $0.layer = nil }
    })
    let lclMeshes = base.structure("knee.lcl")?.meshIDs ?? []
    list.append(ValidationCase(name: "part without meshes", reason: .missingReference,
                               naming: ["knee.lcl"] + lclMeshes) { r in
        changeStructure(&r, "knee.lcl") { $0.meshIDs = [] }
    })
    list.append(ValidationCase(name: "part with four meshes", reason: .missingReference,
                               naming: ["knee.femur"]) { r in
        for index in 0..<3 {
            let id = "mesh.femur.extra\(index)"
            r.meshes.append(ProceduralMeshDeclaration(id: id, kind: .sphere))
            changeStructure(&r, "knee.femur") { $0.meshIDs.append(id) }
        }
    })
    list.append(ValidationCase(name: "two roots", reason: .missingReference,
                               naming: ["knee.femur", "knee.joint"]) { r in
        changeStructure(&r, "knee.femur") { $0.parent = nil }
    })
    list.append(ValidationCase(name: "no root", reason: .parentCycle, naming: []) { r in
        changeStructure(&r, "knee.joint") { $0.parent = "knee.femur" }
    })
    list.append(ValidationCase(name: "two-part cycle", reason: .parentCycle,
                               naming: ["knee.femur", "knee.tibia"]) { r in
        changeStructure(&r, "knee.femur") { $0.parent = "knee.tibia" }
        changeStructure(&r, "knee.tibia") { $0.parent = "knee.femur" }
    })
    list.append(ValidationCase(name: "bad text license", reason: .badLicense, naming: ["cc-by-nc"]) { r in
        r.manifest.textLicense = "cc-by-nc"
    })
    list.append(ValidationCase(name: "bad geometry license", reason: .badLicense, naming: ["proprietary"]) { r in
        r.manifest.geometryLicense = "proprietary"
    })
    list.append(ValidationCase(name: "bad citation license", reason: .badLicense, naming: ["all-rights"]) { r in
        if !r.manifest.citations.isEmpty { r.manifest.citations[0].license = "all-rights" }
    })
    list.append(ValidationCase(name: "NaN bound", reason: .nonFinite, naming: []) { r in
        r.bounds.min.x = .nan
    })
    list.append(ValidationCase(name: "infinite bound", reason: .nonFinite, naming: []) { r in
        r.bounds.max.y = .infinity
    })
    list.append(ValidationCase(name: "empty bounds", reason: .nonFinite, naming: []) { r in
        r.bounds.max = r.bounds.min
    })
}

/// Adds the synonym collision cases to `list`.
private func appendSynonymCases(_ list: inout [ValidationCase], _ base: AnatomyRegion) {
    let femurName = base.structure("knee.femur")?.englishName ?? "Femur"
    list.append(ValidationCase(name: "synonym equals a name", reason: .collidingSynonym,
                               naming: ["knee.tibia", femurName]) { r in
        changeStructure(&r, "knee.tibia") { $0.synonyms.append(femurName.uppercased()) }
    })
    let femurStandard = base.structure("knee.femur")?.standardName ?? "Femur"
    list.append(ValidationCase(name: "synonym equals a standard name", reason: .collidingSynonym,
                               naming: ["knee.fibula", femurStandard]) { r in
        changeStructure(&r, "knee.fibula") { $0.synonyms.append(femurStandard.lowercased()) }
    })
    for structure in base.structures where structure.id != "knee.patella" {
        guard let synonym = structure.synonyms.first else { continue }
        list.append(ValidationCase(name: "synonym equals a synonym", reason: .collidingSynonym,
                                   naming: ["knee.patella", synonym]) { r in
            changeStructure(&r, "knee.patella") { $0.synonyms.append(synonym.uppercased()) }
        })
        break
    }
}

/// Every validation case for `base`.
private func allValidationCases(_ base: AnatomyRegion) -> [ValidationCase] {
    var list: [ValidationCase] = []
    appendStructureCases(&list, base)
    appendReferenceCases(&list, base)
    appendSynonymCases(&list, base)
    return list
}

/// The refusal `validate` gives for `item` applied to `base`.
private func refusalOf(_ item: ValidationCase, _ base: AnatomyRegion) -> ContentRefusal? {
    var region = base
    item.mutate(&region)
    return AnatomyContent.validate(region)
}

@Suite struct ContentValidationTests {
    /// Runs every case expecting `reason`, checking the reason and the named id or word.
    private func runValidationCases(_ reason: ContentRefusal.Reason) throws {
        let base = try AnatomyContent.bundledRightKnee()
        let cases = allValidationCases(base).filter { $0.reason == reason }
        #expect(!cases.isEmpty, "\(reason)")
        for item in cases {
            let refusal = refusalOf(item, base)
            #expect(refusal?.reason == reason, "\(item.name): \(String(describing: refusal))")
            let sentence = (refusal?.sentence ?? "").lowercased()
            #expect(!sentence.isEmpty, "\(item.name)")
            if !item.naming.isEmpty {
                let named = item.naming.contains { sentence.contains($0.lowercased()) }
                #expect(named, "\(item.name): \(sentence)")
            }
        }
    }

    @Test func duplicateIDsAreRefused() throws { try runValidationCases(.duplicateID) }
    @Test func emptyTextIsRefused() throws { try runValidationCases(.emptyText) }
    @Test func clinicalTextIsRefused() throws { try runValidationCases(.clinicalText) }
    @Test func unsourcedPartsAreRefused() throws { try runValidationCases(.unsourced) }
    @Test func missingReferencesAreRefused() throws { try runValidationCases(.missingReference) }
    @Test func parentCyclesAreRefused() throws { try runValidationCases(.parentCycle) }
    @Test func badLicensesAreRefused() throws { try runValidationCases(.badLicense) }
    @Test func nonFiniteBoundsAreRefused() throws { try runValidationCases(.nonFinite) }
    @Test func collidingSynonymsAreRefused() throws { try runValidationCases(.collidingSynonym) }

    @Test func anAsymmetricNeighbourNamesThePatella() throws {
        let base = try AnatomyContent.bundledRightKnee()
        let patella = try #require(base.structure("knee.patella"))
        let femur = try #require(base.structure("knee.femur"))
        #expect(patella.neighbours.contains("knee.femur") && femur.neighbours.contains("knee.patella"))
        var region = base
        changeStructure(&region, "knee.patella") { $0.neighbours.removeAll { $0 == "knee.femur" } }
        let refusal = AnatomyContent.validate(region)
        #expect(refusal?.reason == .missingReference)
        #expect(refusal?.sentence.contains("knee.patella") == true)
    }

    /// T-A17-115 (SC-A17-102): the root `knee.joint` groups the parts; a root with a layer or with a mesh is damaged
    /// content, and the sentence names the root.
    @Test func aRootWithALayerOrAMeshIsDamaged() throws {
        let base = try AnatomyContent.bundledRightKnee()
        var layered = base
        changeStructure(&layered, "knee.joint") { $0.layer = .bones }
        let layeredRefusal = AnatomyContent.validate(layered)
        #expect(layeredRefusal?.reason == .damaged)
        #expect(layeredRefusal?.sentence.contains("knee.joint") == true)

        var meshed = base
        meshed.meshes.append(ProceduralMeshDeclaration(id: "mesh.joint.capsule", kind: .revolution))
        changeStructure(&meshed, "knee.joint") { $0.meshIDs = ["mesh.joint.capsule"] }
        let meshedRefusal = AnatomyContent.validate(meshed)
        #expect(meshedRefusal?.reason == .damaged)
        #expect(meshedRefusal?.sentence.contains("knee.joint") == true)
    }

    @Test func everyLabelResolvesToAStructureAndItsFirstMesh() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let labels = AnatomyContent.labels(region)
        #expect(labels.count == 14)
        let meshIDs = Set(region.meshes.map(\.id))
        #expect(!labels.contains { $0.structureID == "knee.joint" })
        for label in labels {
            let structure = region.structure(label.structureID)
            #expect(structure != nil, "\(label.structureID)")
            #expect(structure?.englishName == label.text, "\(label.structureID)")
            #expect(meshIDs.contains(label.anchorMeshID), "\(label.anchorMeshID)")
            #expect(structure?.meshIDs.first == label.anchorMeshID, "\(label.structureID)")
        }
        #expect(Set(labels.map(\.structureID)).count == 14)
    }

    @Test func everyRefusalReasonIsProducedBySomeCase() throws {
        let base = try AnatomyContent.bundledRightKnee()
        var produced = Set<ContentRefusal.Reason>()
        for item in allValidationCases(base) {
            if let refusal = refusalOf(item, base) { produced.insert(refusal.reason) }
        }
        let encoded = AnatomyContent.encoded(base)
        var object = try #require((try JSONSerialization.jsonObject(with: encoded)) as? [String: Any])
        object["schema"] = 2
        let newer = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        var large = encoded
        large.append(Data(repeating: 0x20, count: max(AnatomyContent.maxBytes + 1 - encoded.count, 0)))
        let decodeInputs = [Data("{".utf8), newer, large]
        for data in decodeInputs {
            if case .failure(let refusal) = AnatomyContent.decode(data) { produced.insert(refusal.reason) }
        }
        for reason in ContentRefusal.Reason.allCases {
            #expect(produced.contains(reason), "\(reason)")
        }
    }
}
