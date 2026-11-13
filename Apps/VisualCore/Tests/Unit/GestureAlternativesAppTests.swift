// GestureAlternativesAppTests — feature 226 (R02-F26) T-R02F26-007 (FR-R02F26-010; SC-R02F26-002): every canvas gesture
// of an experience has a native control. The debug experience passes; a planted gap is named. A01–A04 declare their
// sets in their next gates (analysis D1).
import XCTest
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualCoreApp

@MainActor
final class GestureAlternativesAppTests: XCTestCase {
    func testTheDebugExperienceHasANativeControlForEveryGestureAction() throws {
        let storage = try TestStorage(self)
        let id = try XCTUnwrap(ExperienceID(rawValue: "a01.generative-art-studio"))
        let presenter = DebugPresenter(experienceID: id, launch: storage.launch(id))
        XCTAssertEqual(presenter.nativeActions, ["tap"])
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions), [])
    }

    func testAPlantedGestureWithoutAControlIsNamed() throws {
        let storage = try TestStorage(self)
        let id = try XCTUnwrap(ExperienceID(rawValue: "a01.generative-art-studio"))
        let presenter = DebugPresenter(experienceID: id, launch: storage.launch(id))
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions.union(["zoom"]),
                                                   native: presenter.nativeActions), ["zoom"])
    }
}
