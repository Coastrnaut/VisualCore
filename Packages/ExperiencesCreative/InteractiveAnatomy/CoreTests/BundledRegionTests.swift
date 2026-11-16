// BundledRegionTests — feature 124 (A17-P01) T-A17-105 (SC-A17-101; FR-A17-102, FR-A17-104, FR-A17-105). The bundled
// right knee, host-free and short: it loads and validates; it holds the root and 14 parts; every part has a source, a
// description, 1–3 meshes and its layer (4 bones, 4 cartilage, 6 ligaments); every neighbour relation is
// symmetric and none lists itself; every citation license is allowed; the
// review sentence is "Not reviewed by a clinician."; the encoded region fits the size limit.
import Foundation
import Testing
import VisualCoreMath
@testable import InteractiveAnatomyCore

@Suite struct BundledRegionTests {
    /// The 14 joint parts and the layer each belongs to.
    private static let bundledPartLayers: [(String, AnatomyLayer)] = [
        ("knee.femur", .bones), ("knee.tibia", .bones), ("knee.fibula", .bones), ("knee.patella", .bones),
        ("knee.femoral-cartilage", .cartilage), ("knee.tibial-cartilage", .cartilage),
        ("knee.medial-meniscus", .cartilage), ("knee.lateral-meniscus", .cartilage),
        ("knee.acl", .ligaments), ("knee.pcl", .ligaments), ("knee.mcl", .ligaments), ("knee.lcl", .ligaments),
        ("knee.patellar-ligament", .ligaments), ("knee.quadriceps-tendon", .ligaments),
    ]

    @Test func theBundledKneeLoadsAndValidates() throws {
        let region = try AnatomyContent.bundledRightKnee()
        #expect(AnatomyContent.validate(region) == nil)
        #expect(region.id == "region.knee.right")
        #expect(region.schema == AnatomyRegion.schemaVersion)
    }

    @Test func theRootHasNoMeshesAndNoLayer() throws {
        let region = try AnatomyContent.bundledRightKnee()
        #expect(region.structures.count == 15)
        let root = region.root
        #expect(root?.id == "knee.joint")
        #expect(root?.parent == nil)
        #expect(root?.layer == nil)
        #expect(root?.meshIDs.isEmpty == true)
    }

    @Test func everyPartHasASourceADescriptionMeshesAndItsLayer() throws {
        let region = try AnatomyContent.bundledRightKnee()
        var counts: [AnatomyLayer: Int] = [:]
        for (id, layer) in Self.bundledPartLayers {
            let part = region.structure(id)
            #expect(part != nil, "\(id)")
            guard let part else { continue }
            #expect(part.parent == "knee.joint", "\(id)")
            #expect(part.layer == layer, "\(id)")
            #expect(!part.sourceRefs.isEmpty, "\(id)")
            #expect(!part.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(id)")
            #expect((1...3).contains(part.meshIDs.count), "\(id)")
            counts[layer, default: 0] += 1
        }
        #expect(counts[.bones] == 4 && counts[.cartilage] == 4 && counts[.ligaments] == 6)
        for layer in AnatomyLayer.allCases {
            #expect(region.structures.contains { $0.layer == layer }, "\(layer)")
        }
    }

    @Test func everyNeighbourRelationIsSymmetric() throws {
        let region = try AnatomyContent.bundledRightKnee()
        for structure in region.structures {
            #expect(!structure.neighbours.contains(structure.id), "\(structure.id)")
            for neighbour in structure.neighbours {
                let other = region.structure(neighbour)
                #expect(other != nil, "\(structure.id) → \(neighbour)")
                #expect(other?.neighbours.contains(structure.id) == true, "\(structure.id) ↔ \(neighbour)")
            }
        }
    }

    @Test func theManifestIsLicensedAndNotReviewed() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let manifest = region.manifest
        #expect(ContentManifest.allowedLicenses.contains(manifest.textLicense))
        #expect(ContentManifest.allowedLicenses.contains(manifest.geometryLicense))
        #expect(!manifest.citations.isEmpty)
        for citation in manifest.citations {
            #expect(ContentManifest.allowedLicenses.contains(citation.license), "\(citation.id)")
        }
        let citationIDs = Set(manifest.citations.map(\.id))
        #expect(citationIDs.contains("ta-1998") && citationIDs.contains("original-descriptions"))
        #expect(manifest.review.status == ReviewStatus.notReviewed)
        #expect(manifest.reviewSentence == "Not reviewed by a clinician.")
    }

    @Test func theEncodedRegionFitsTheSizeLimit() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let size = AnatomyContent.encoded(region).count
        #expect(size > 0 && size <= AnatomyContent.maxBytes)
    }
}
