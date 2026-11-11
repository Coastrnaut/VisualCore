// AutomationViewTests — feature 017 T-A01-603 (FR-A01-608): the shared view hosts a scene, runs the mode after layout,
// writes a report and calls terminate exactly once.
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import VisualCoreAutomation
import VisualCoreRendering

@MainActor
final class AutomationViewTests: XCTestCase {
    func testRunsModeOnHostedSceneAndTerminates() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("automation-view-\(UUID().uuidString)")
        var codes: [Int32] = []
        var configured: CGFloat = 0
        let view = AutomationView(mode: "smoke", bundleID: "dev.visualcore.tests",
                                  makeScene: { ClearColorScene(red: 0.1, green: 0.5, blue: 0.9) },
                                  configure: { _, scale in configured = scale },
                                  outputDirectory: dir, terminate: { codes.append($0) })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 120, height: 160))
        window.rootViewController = UIHostingController(rootView: view.ignoresSafeArea())
        window.makeKeyAndVisible()
        let deadline = Date().addingTimeInterval(20)
        while codes.isEmpty, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        XCTAssertEqual(codes, [0], "smoke passes and terminates once")
        XCTAssertGreaterThan(configured, 0, "configure got the display scale")
        let reports = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertEqual(reports.count, 1)
        let report = try JSONDecoder().decode(AutomationReport.self, from: Data(contentsOf: reports[0]))
        XCTAssertEqual(report.mode, "smoke")
        window.isHidden = true
    }
}
