// TemplateTests — feature 138 (A19-P01) T-A19-108 (FR-A19-103; SC-A19-102; clarification Q3). Nine templates with the
// exact portrait sizes of Apple's published specifications, their provenance, landscape swapping the edges, lookup by
// id, and the approximate safe-area guides.
import Foundation
import Testing
import VisualCoreScenes
@testable import LivingWallpapersCore

@Suite struct TemplateTests {
    /// The expected portrait sizes of clarification Q3, by id.
    private static let expected: [(id: String, width: Int, height: Int, family: DeviceFamily)] = [
        ("iphone-16-pro-max", 1320, 2868, .iPhone),
        ("iphone-16-pro", 1206, 2622, .iPhone),
        ("iphone-16-plus", 1290, 2796, .iPhone),
        ("iphone-16", 1179, 2556, .iPhone),
        ("iphone-se-3", 750, 1334, .iPhone),
        ("ipad-pro-13-m4", 2064, 2752, .iPad),
        ("ipad-pro-11-m4", 1668, 2420, .iPad),
        ("ipad-air-11-m2", 1640, 2360, .iPad),
        ("ipad-mini-a17-pro", 1488, 2266, .iPad),
    ]

    @Test func nineTemplatesHaveTheExactSizes() {
        #expect(CanvasTemplates.all.count == 9)
        #expect(CanvasTemplates.all.map(\.id) == Self.expected.map(\.id))
        for (template, row) in zip(CanvasTemplates.all, Self.expected) {
            #expect(template.portraitWidth == row.width, "\(row.id)")
            #expect(template.portraitHeight == row.height, "\(row.id)")
            #expect(template.family == row.family, "\(row.id)")
            #expect(!template.device.isEmpty)
        }
    }

    @Test func everyTemplateRecordsItsProvenance() {
        #expect(CanvasTemplates.provenance == "Apple technical specifications, retrieved 2026-11-17")
        for template in CanvasTemplates.all {
            #expect(template.provenance == "Apple technical specifications, retrieved 2026-11-17")
        }
    }

    @Test func landscapeSwapsTheEdges() {
        for template in CanvasTemplates.all {
            let portrait = template.size(for: .portrait)
            let landscape = template.size(for: .landscape)
            #expect(portrait == ExportSize(width: template.portraitWidth, height: template.portraitHeight))
            #expect(landscape == ExportSize(width: template.portraitHeight, height: template.portraitWidth))
            #expect(portrait.height > portrait.width)
            #expect(landscape.width > landscape.height)
        }
    }

    @Test func templatesAreFoundById() {
        for template in CanvasTemplates.all {
            #expect(CanvasTemplates.template(id: template.id) == template)
        }
        #expect(CanvasTemplates.template(id: "iphone-99") == nil)
    }

    @Test func theSafeAreaGuidesAreTheApproximateFractions() {
        #expect(SafeAreaGuide.approximate == SafeAreaGuide(top: 0.22, bottom: 0.10, side: 0.04))
        for template in CanvasTemplates.all {
            #expect(template.safeArea == .approximate)
        }
    }
}
