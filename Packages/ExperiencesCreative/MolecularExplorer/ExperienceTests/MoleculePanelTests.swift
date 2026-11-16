// MoleculePanelTests — feature 112 (A15-P03) T-A15-306 (FR-A15-320–323; clarifications Q4, Q5; SC-A15-303,
// SC-A15-304; edge cases "A selected atom behind others", "An inferred bond"). The metadata panel, the canvas
// description, the bond styles, the labels and the announcements of Molecular Explorer through the one app's session
// host on the simulator, short runs only (each test well under 10 s, no wall-clock assertion): the panel lines name
// the selected atom's element, place, position and radii and each bond with its order and "recorded" or "inferred";
// the description ends with the selected atom; caffeine's double bonds drawn as two sticks change the drawn pixels
// compared with drawing every half as one stick; each action announces at most once and a selection change is
// announced; the placed labels never overlap, the selected atom's label comes first and its ring is shown.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation
import VisualCoreUI

/// The panel, the words and the overlay data of the selected atom.
@MainActor
final class MoleculePanelTests: XCTestCase {
    /// The view size in points of every drawn test.
    private let size = CGSize(width: 240, height: 160)

    func testThePanelLinesNameTheAtomAndItsBonds() throws {
        let caffeine = try XCTUnwrap(MoleculeCore.molecule(index: 4))
        XCTAssertEqual(MoleculePresenter.atomPanel(caffeine, atom: 2),
                       ["Nitrogen (N), atom 3 of 24", "Position x \u{2212}0.97, y \u{2212}1.31, z 0.00 Å",
                        "Covalent radius 0.71 Å, van der Waals radius 1.55 Å"])
        XCTAssertEqual(MoleculePresenter.bondLines(caffeine, atom: 2),
                       ["Single bond to carbon, atom 8, recorded", "Single bond to carbon, atom 10, recorded",
                        "Single bond to carbon, atom 12, recorded"])
        XCTAssertEqual(MoleculePresenter.bondLines(caffeine, atom: 0), ["Double bond to carbon, atom 9, recorded"])
        XCTAssertEqual(MoleculePresenter.atomPanel(caffeine, atom: 0)[1], "Position x 0.47, y 2.57, z 0.00 Å")
        XCTAssertEqual(MoleculePresenter.atomPanel(caffeine, atom: 24), [])
        XCTAssertEqual(MoleculePresenter.bondLines(caffeine, atom: -1), [])
        // An inferred bond is named inferred and single.
        let water = try XCTUnwrap(MoleculeCore.molecule(index: 0))
        let inferred = try Molecule.make(id: "water-inferred", title: "Water", atoms: water.atoms,
                                         bonds: BondInference.bonds(for: water.atoms), source: water.source).get()
        XCTAssertEqual(MoleculePresenter.bondLines(inferred, atom: 0),
                       ["Single bond to hydrogen, atom 2, inferred", "Single bond to hydrogen, atom 3, inferred"])
        XCTAssertEqual(MoleculePresenter.decimal(-0.0004), "0.00", "no sign on a value that rounds to zero")
        XCTAssertEqual(MoleculePresenter.decimal(-1.3125), "\u{2212}1.31")
        XCTAssertEqual(MoleculePresenter.orderWord(3), "Triple")
        XCTAssertEqual(MoleculePresenter.panWords(.default), "View centred")
        XCTAssertEqual(MoleculePresenter.panWords(CameraSettings(turnSteps: 2, tiltSteps: 2, zoomSteps: 0, panX: 2,
                                                                 panY: -1)), "View panned 2 right and 1 down")
    }

    func testTheMirrorAndTheDescriptionNameTheSelectedAtom() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        XCTAssertTrue(presenter.send("atom.select", [2], through: shell.port).isAccepted)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(presenter.mirror.selectedAtom, 2)
        XCTAssertEqual(presenter.mirror.atomCount, 24)
        XCTAssertEqual(presenter.mirror.atomWords, "Nitrogen (N), atom 3 of 24")
        XCTAssertEqual(presenter.mirror.atomPanel.count, 3)
        XCTAssertEqual(presenter.mirror.bondLines.count, 3)
        XCTAssertEqual(shell.accessibilitySummary,
                       "Molecular Explorer: Caffeine, C8H10N4O2; 24 atoms, 25 bonds; elements carbon, hydrogen, "
                       + "nitrogen, oxygen; ball-and-stick; selected nitrogen, atom 3.")
        XCTAssertEqual(presenter.send("atom.select", [30], through: shell.port).code, "action.rule.a15.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "There is no such atom.")
        XCTAssertTrue(presenter.send("atom.clear", through: shell.port).isAccepted)
        XCTAssertEqual(presenter.send("atom.clear", through: shell.port).code, "action.rule.a15.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "No atom is selected.")
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(presenter.mirror.atomWords, MoleculePresenter.noAtomWords)
        XCTAssertEqual(presenter.mirror.atomPanel, [])
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("oxygen; ball-and-stick."), shell.accessibilitySummary)
        XCTAssertNotNil(shell.canvasOverlay, "the labels and the ring are drawn over the canvas")
        session.close()
    }

    func testCaffeinesDoubleBondsChangeTheDrawnPixels() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        let styled = try MoleculeTest.picture(session)
        XCTAssertEqual(shell.presenter.lastSticksDrawn, 58, "four double bonds give two sticks per half")
        XCTAssertEqual(shell.presenter.lastItemCount, 82)
        shell.presenter.drawsBondStyles = false
        let plain = try MoleculeTest.picture(session)
        XCTAssertEqual(shell.presenter.lastSticksDrawn, 50, "one stick per half")
        XCTAssertNotEqual(StableHash.sha256Hex(styled.rgba), StableHash.sha256Hex(plain.rgba))
        XCTAssertGreaterThan(MoleculeTest.differingPixels(styled.rgba, plain.rgba), 0, "the bond order is visible")
        shell.presenter.drawsBondStyles = true
        let again = try MoleculeTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(styled.rgba), StableHash.sha256Hex(again.rgba))
        session.close()
    }

    func testEachActionAnnouncesAtMostOnceAndASelectionChangeIsAnnounced() async throws {
        let sink = RecordingAnnouncementSink()
        let presenter = MoleculePresenter(experienceID: MoleculeTest.id, announcementSink: sink, displayScale: 2)
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size, presenter: presenter)
        let steps: [(String, [Double], String?)] = [
            ("molecule.select", [4], nil),
            ("atom.select", [2], "Nitrogen (N), atom 3 of 24"),
            ("atom.next", [], "Nitrogen (N), atom 4 of 24"),
            ("camera.orbit", [1], nil),
            ("display.mode", [1], nil),
            ("camera.pan", [1, 0], nil),
            ("atom.previous", [], "Nitrogen (N), atom 3 of 24"),
            ("atom.clear", [], MoleculePresenter.noAtomWords),
            ("atom.previous", [], "Hydrogen (H), atom 24 of 24"),
            ("molecule.previous", [], nil),
        ]
        for (control, values, words) in steps {
            let before = sink.announced.count
            XCTAssertTrue(presenter.send(control, values, through: shell.port).isAccepted, control)
            try MoleculeTest.frames(session, 2)
            _ = shell.accessibilitySummary
            let made = sink.announced.count - before
            XCTAssertLessThanOrEqual(made, 1, "\(control): at most one announcement")
            if let words {
                XCTAssertEqual(made, 1, "\(control): the selection change is announced")
                XCTAssertEqual(sink.announced.last, words, control)
            } else {
                XCTAssertEqual(made, 0, "\(control): nothing to announce")
            }
        }
        XCTAssertEqual(presenter.announcementCount, sink.announced.count)
        session.close()
    }

    func testTheLabelsNeverOverlapAndTheSelectedAtomComesFirstWithItsRing() async throws {
        let presenter = MoleculePresenter(experienceID: MoleculeTest.id, announcementSink: RecordingAnnouncementSink(),
                                          displayScale: 2)
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size, presenter: presenter)
        for index in 0..<MoleculeCore.moleculeCount {
            XCTAssertTrue(shell.handle(control: "molecule.select", values: [Double(index)]).isAccepted)
            try MoleculeTest.frames(session, 1)
            let labels = presenter.mirror.labels
            XCTAssertFalse(labels.isEmpty, "molecule \(index) has labels")
            for a in labels.indices {
                for b in labels.indices where b > a {
                    XCTAssertFalse(LabelLayout.overlaps(labels[a].box, labels[b].box), "molecule \(index) \(a) \(b)")
                }
            }
            XCTAssertNil(presenter.mirror.ring, "no ring without a selection")
        }
        XCTAssertTrue(shell.handle(control: "atom.select", values: [5]).isAccepted)
        try MoleculeTest.frames(session, 1)
        let canvas = try XCTUnwrap(presenter.lastCanvas)
        XCTAssertEqual(presenter.mirror.canvasSize, Vec2(canvas.x / 2, canvas.y / 2),
                       "points before the overlay reports")
        XCTAssertEqual(presenter.mirror.labels.first?.index, 5, "the selected atom is labelled first")
        XCTAssertEqual(presenter.mirror.labels.first?.symbol, "N")
        let ring = try XCTUnwrap(presenter.mirror.ring)
        XCTAssertGreaterThan(ring.radius, 1, "the ring surrounds the atom's projected outline")
        XCTAssertEqual(presenter.mirror.labels, presenter.lastLabels)
        session.close()
    }
}
