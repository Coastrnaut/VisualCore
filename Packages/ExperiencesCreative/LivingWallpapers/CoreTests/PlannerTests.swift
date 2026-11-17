// PlannerTests — feature 138 (A19-P01) T-A19-108 (FR-A19-104; SC-A19-102, SC-A19-103; clarification Q3). A template
// that fits is planned at exactly its size; at limits 2048, 4096 and 8192 every larger template is refused with the
// ExportGeometry size at its aspect, which fits; limit 0 is no-limit; a small pixel cap refuses too.
import Foundation
import Testing
import VisualCoreScenes
@testable import LivingWallpapersCore

@Suite struct PlannerTests {
    /// The default project on `template` in `orientation`.
    private static func project(_ template: CanvasTemplate, _ orientation: Orientation) -> WallpaperProject {
        var project = WallpaperProject.default
        project.template = template.id
        project.orientation = orientation
        return project
    }

    @Test func aFittingTemplateIsPlannedAtItsExactSize() throws {
        let plan = try ExportPlanner.plan(project: .default, maxEdge: 4096).get()
        #expect(plan == ExportPlan(format: .png, width: 1206, height: 2622, profile: .sRGB, fallback: false))
        var landscape = WallpaperProject.default
        landscape.template = "iphone-16"
        landscape.orientation = .landscape
        let odd = try ExportPlanner.plan(project: landscape, maxEdge: 2556).get()
        #expect(odd.width == 2556 && odd.height == 1179)
        #expect(odd.fallback == false)
    }

    @Test func templatesAboveTheLimitAreRefusedWithAFittingOffer() {
        for limit in [2048, 4096, 8192] {
            let geometry = ExportGeometry(maxEdge: limit, maxPixels: ExportGeometry.defaultMaxPixels)
            for template in CanvasTemplates.all {
                for orientation in Orientation.allCases {
                    let size = template.size(for: orientation)
                    let result = ExportPlanner.plan(project: Self.project(template, orientation), maxEdge: limit)
                    if size.longEdge <= limit {
                        let plan = try? result.get()
                        #expect(plan?.size == size, "\(template.id) \(orientation) at \(limit)")
                        continue
                    }
                    let aspect = ExportAspect(id: template.id, title: template.device, width: size.width,
                                              height: size.height)!
                    let expected = geometry.size(longEdge: size.longEdge, aspect: aspect)
                    guard case let .failure(.doesNotFit(id, offered)) = result else {
                        Issue.record("\(template.id) \(orientation) at \(limit) was not refused")
                        continue
                    }
                    #expect(id == template.id)
                    #expect(offered == expected)
                    #expect(offered.width <= limit && offered.height <= limit)
                    #expect(offered.pixelCount <= ExportGeometry.defaultMaxPixels)
                    #expect((offered.width > offered.height) == (size.width > size.height))
                }
            }
        }
    }

    @Test func atLimit2048OnlyTheSmallestIPhoneFits() {
        var fitting: [String] = []
        for template in CanvasTemplates.all {
            if case .success = ExportPlanner.plan(project: Self.project(template, .portrait), maxEdge: 2048) {
                fitting.append(template.id)
            }
        }
        #expect(fitting == ["iphone-se-3"])
    }

    @Test func noLimitIsRefused() {
        guard case .failure(.noLimit) = ExportPlanner.plan(project: .default, maxEdge: 0) else {
            Issue.record("maxEdge 0 was not refused as no-limit")
            return
        }
        guard case .failure(.noLimit) = ExportPlanner.plan(project: .default, maxEdge: -5) else {
            Issue.record("a negative maxEdge was not refused as no-limit")
            return
        }
        #expect(ExportRefusal.noLimit.code == "no-limit")
        #expect(ExportRefusal.noLimit.offeredPlan(format: .png) == nil)
    }

    @Test func aSmallPixelCapRefusesToo() {
        let cap = 1_000_000
        let result = ExportPlanner.plan(project: .default, maxEdge: 8192, maxPixels: cap)
        guard case let .failure(refusal) = result, case let .doesNotFit(id, offered) = refusal else {
            Issue.record("a 1,000,000-pixel cap did not refuse iphone-16-pro")
            return
        }
        #expect(id == "iphone-16-pro")
        #expect(offered.pixelCount <= cap)
        let aspect = ExportAspect(id: "iphone-16-pro", title: "iPhone 16 Pro", width: 1206, height: 2622)!
        #expect(offered == ExportGeometry(maxEdge: 8192, maxPixels: cap).size(longEdge: 2622, aspect: aspect))
        #expect(refusal.code == "does-not-fit")
        let fallback = refusal.offeredPlan(format: .png)
        #expect(fallback == ExportPlan(format: .png, width: offered.width, height: offered.height, fallback: true))
    }

    @Test func anUnknownTemplateIsRefused() {
        var project = WallpaperProject.default
        project.template = "iphone-99"
        guard case .failure(.unknownTemplate("iphone-99")) = ExportPlanner.plan(project: project, maxEdge: 4096) else {
            Issue.record("an unknown template was planned")
            return
        }
    }
}
