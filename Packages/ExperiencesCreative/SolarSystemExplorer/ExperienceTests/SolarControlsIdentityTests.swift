// SolarControlsIdentityTests — feature 108 (A14-P06) T-A14-609 (FR-A14-630). The host redraws its view on every
// revision of the action port, and the shell adds a revision on every frame in which a simulation step ran, so the
// controls view is rebuilt about once per frame. SwiftUI keeps the controls (and an open Body or Tour menu, or the
// Scale picker's selection) only when the rebuilt view compares equal to the previous one. A stored closure never
// compares equal; with Now, Save view and Restore view as closures the Body menu closed again at once and the
// interface tests waited for animations that never ended. The controls therefore hold references only: the port,
// the mirror and the presenter. Short run, no wall-clock assertion.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import VisualCoreExperienceHost

@MainActor
final class SolarControlsIdentityTests: XCTestCase {
    /// Every stored property of the controls is a class reference (no closure, no value that changes per build).
    func testTheControlsHoldOnlyReferences() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session)
        let controls = SolarControls(port: shell.port, mirror: shell.presenter.mirror, presenter: shell.presenter)
        let children = Mirror(reflecting: controls).children
        XCTAssertEqual(children.compactMap(\.label), ["port", "mirror", "presenter"])
        for child in children {
            let type = String(describing: Swift.type(of: child.value))
            XCTAssertFalse(type.contains("->"), "\(child.label ?? "?") is a closure: \(type)")
            XCTAssertEqual(Mirror(reflecting: child.value).displayStyle, .class,
                           "\(child.label ?? "?") is not a class reference: \(type)")
        }
        session.close()
    }
}
