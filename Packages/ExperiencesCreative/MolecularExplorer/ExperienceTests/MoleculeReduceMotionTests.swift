// MoleculeReduceMotionTests — feature 115 (A15-P06) T-A15-615 (FR-A15-623). Molecular Explorer has no animated
// motion and nothing flashes: every camera step, reset and molecule change cuts to the new view in one frame. So the
// registry's factory `MolecularExplorerExperience.make(id:storage:reduceMotion:reduceFlashing:)` gives the same
// experience whatever the two settings are. Two sessions, one with both settings on and one with both off, play the
// same actions (a molecule choice, camera steps, a reset, an atom selection, a mode switch); after each action the
// engine digests, the drawn atom, stick and item counts and the pixels of a frame are the same. Short: a few frames
// at 240 × 160; no prompt, no network.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Reduce Motion and Reduce Flashing change nothing in Molecular Explorer.
@MainActor
final class MoleculeReduceMotionTests: XCTestCase {
    /// The actions both sessions play, in order.
    private let actions: [(control: String, values: [Double])] = [
        ("molecule.select", [4]), ("camera.orbit", [1]), ("camera.tilt", [1]), ("camera.zoom", [1]),
        ("view.reset", []), ("atom.next", []), ("display.mode", [1]), ("molecule.select", [3]),
    ]

    /// Opens the registry's experience with both accessibility settings at `reduced` and returns its shell.
    private func open(_ session: ExperienceSession, reduced: Bool) async throws -> ExperienceShell<MoleculePresenter> {
        let id = MoleculeTest.id
        let storage = TemporaryMoleculeStorage().storage
        var made: ExperienceShell<MoleculePresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let experience = MolecularExplorerExperience.make(id: id, storage: storage, reduceMotion: reduced,
                                                              reduceFlashing: reduced)
            made = experience as? ExperienceShell<MoleculePresenter>
            return experience
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(origin: .zero, size: CGSize(width: 240, height: 160))
            view.layoutIfNeeded()
        }
        try MoleculeTest.frames(session, 1)
        return try XCTUnwrap(made, "the registry's factory gives the presenter's shell")
    }

    /// The same actions give the same digests, drawn counts and pixels with the settings on and off.
    func testReduceMotionAndReduceFlashingChangeNothing() async throws {
        let plain = ExperienceSession()
        let reduced = ExperienceSession()
        let plainShell = try await open(plain, reduced: false)
        let reducedShell = try await open(reduced, reduced: true)
        XCTAssertEqual(try plainShell.engine.digest(), try reducedShell.engine.digest(), "the first state")
        for action in actions {
            XCTAssertTrue(plainShell.handle(control: action.control, values: action.values).isAccepted, action.control)
            XCTAssertTrue(reducedShell.handle(control: action.control, values: action.values).isAccepted,
                          action.control)
            let a = try MoleculeTest.picture(plain)
            let b = try MoleculeTest.picture(reduced)
            XCTAssertEqual(try plainShell.engine.digest(), try reducedShell.engine.digest(), action.control)
            XCTAssertEqual(plainShell.presenter.lastAtomsDrawn, reducedShell.presenter.lastAtomsDrawn, action.control)
            XCTAssertEqual(plainShell.presenter.lastSticksDrawn, reducedShell.presenter.lastSticksDrawn,
                           action.control)
            XCTAssertEqual(plainShell.presenter.lastItemCount, reducedShell.presenter.lastItemCount, action.control)
            XCTAssertEqual(MoleculeTest.differingPixels(a.rgba, b.rgba), 0, "\(action.control): the same picture")
        }
        plain.close()
        reduced.close()
    }
}
