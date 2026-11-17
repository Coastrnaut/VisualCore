// ExportNoticeTests — feature 140 (A19-P03) T-A19-305 (FR-A19-302, FR-A19-303; SC-A19-302; clarifications Q2, Q3).
// At limits 2048, 4096 and 8192 every template and orientation the planner refuses gets a notice naming the template
// size, the limit and the offered size, and every one that fits gets none; limit 0 reads "Open a picture to export
// it."; the result line names the format, the read-back size and the profile.
import Foundation
import Testing
import VisualCoreScenes
@testable import LivingWallpapersCore

@Suite struct ExportNoticeTests {
    /// The default project on `template` in `orientation`.
    private static func project(_ template: CanvasTemplate, _ orientation: Orientation) -> WallpaperProject {
        var project = WallpaperProject.default
        project.template = template.id
        project.orientation = orientation
        return project
    }

    @Test func everyRefusedTemplateGetsANoticeWithItsNumbers() {
        var refused = 0
        for limit in [2048, 4096, 8192] {
            for template in CanvasTemplates.all {
                for orientation in Orientation.allCases {
                    let result = ExportPlanner.plan(project: Self.project(template, orientation), maxEdge: limit)
                    let notice = ExportNotice.notice(for: result, limit: limit, orientation: orientation)
                    guard case let .failure(.doesNotFit(_, offered)) = result else {
                        #expect(notice == nil, "\(template.id) \(orientation) at \(limit)")
                        continue
                    }
                    refused += 1
                    let size = template.size(for: orientation)
                    let expected = "\(template.device) is \(size.width) × \(size.height) pixels, larger than this "
                        + "device can render (\(limit)). It will be exported at \(offered.width) × "
                        + "\(offered.height) instead."
                    #expect(notice == expected, "\(template.id) \(orientation) at \(limit)")
                    for number in [size.width, size.height, limit, offered.width, offered.height] {
                        #expect(notice?.contains(String(number)) == true, "\(number) in \(template.id)")
                    }
                }
            }
        }
        #expect(refused > 0)
    }

    @Test func theRefusalOverloadDefaultsToPortrait() {
        let offered = ExportSize(width: 940, height: 2048)
        let refusal = ExportRefusal.doesNotFit(template: "iphone-16-pro", offered: offered)
        #expect(ExportNotice.notice(for: refusal, limit: 2048)
                == "iPhone 16 Pro is 1206 × 2622 pixels, larger than this device can render (2048). It will be "
                + "exported at 940 × 2048 instead.")
        #expect(ExportNotice.notice(for: refusal, limit: 2048, orientation: .landscape)?
            .hasPrefix("iPhone 16 Pro is 2622 × 1206 pixels") == true)
    }

    @Test func limitZeroAsksForAPicture() {
        let result = ExportPlanner.plan(project: .default, maxEdge: 0)
        #expect(ExportNotice.notice(for: result, limit: 0, orientation: .portrait) == "Open a picture to export it.")
        #expect(ExportNotice.notice(for: .noLimit, limit: 0) == "Open a picture to export it.")
    }

    @Test func anUnknownTemplateIsNamedAsUnknown() {
        #expect(ExportNotice.notice(for: .unknownTemplate("iphone-99"), limit: 4096)
                == "This device size is not known.")
        let refusal = ExportRefusal.doesNotFit(template: "iphone-99", offered: ExportSize(width: 10, height: 20))
        #expect(ExportNotice.notice(for: refusal, limit: 4096) == "This device size is not known.")
    }

    @Test func theResultLineNamesFormatSizeAndProfile() {
        let result = ExportResult(width: 1206, height: 2622, profileName: "kCGColorSpaceSRGB", bytes: 123_456)
        let expected: [(ExportFormat, String)] = [(.png, "PNG"), (.jpeg, "JPEG"), (.heic, "HEIC")]
        for (format, name) in expected {
            let plan = ExportPlan(format: format, width: 1206, height: 2622, fallback: false)
            #expect(ExportResultLine.line(plan: plan, result: result) == "\(name), 1206 × 2622 pixels, sRGB")
        }
        let plan = ExportPlan(format: .png, width: 1206, height: 2622, fallback: false)
        let readBack = ExportResult(width: 940, height: 2048, profileName: "kCGColorSpaceDisplayP3", bytes: 1)
        #expect(ExportResultLine.line(plan: plan, result: readBack)
                == "PNG, 940 × 2048 pixels, kCGColorSpaceDisplayP3")
        let untagged = ExportResult(width: 2, height: 3, profileName: nil, bytes: 1)
        #expect(ExportResultLine.line(plan: plan, result: untagged) == "PNG, 2 × 3 pixels, unknown profile")
    }
}
