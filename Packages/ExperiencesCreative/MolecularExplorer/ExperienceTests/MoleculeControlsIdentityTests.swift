// MoleculeControlsIdentityTests — feature 110 (A15-P01) T-A15-106 (FR-A15-131). The host redraws its view on every
// revision of the action port, so the controls view is rebuilt often. SwiftUI keeps the controls (and an open Molecule
// menu) only when the rebuilt view compares equal to the previous one, and a stored closure never compares equal (the
// lesson of feature 108 T-A14-609, docs/automatedtesting.md "App animations complete notification not received"). The
// controls therefore hold references only: the port, the mirror and the presenter. Short run, no wall-clock assertion.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import VisualCoreExperienceHost

/// The controls of Molecular Explorer hold class references only.
@MainActor
final class MoleculeControlsIdentityTests: XCTestCase {
    /// Every stored property of the controls is a class reference (no closure, no value that changes per build).
    func testTheControlsHoldOnlyReferences() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        let controls = MoleculeControls(port: shell.port, mirror: shell.presenter.mirror, presenter: shell.presenter)
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
