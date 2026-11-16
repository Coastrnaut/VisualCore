// MoleculeLibraryUITests — feature 113 (A15-P04) T-A15-405 (FR-A15-401, FR-A15-420, FR-A15-440; SC-A15-401;
// clarifications Q2, Q4). The words and the behaviour behind the Library section, the Recent menu and the Labels picker
// of Molecular Explorer, as unit tests of the controls' words and the presenter (no UI automation): every library
// entry names its molecule, formula, atom and bond counts and its source with the license, taken from the molecule's
// source record; choosing an entry or a recent molecule sends `molecule.select`; the recent menu lists the opened
// molecules newest first ("No recent molecules" when empty); the labels picker changes how many labels the overlay
// shows (all, only the selected atom, none) without an engine action and without changing the digest; and the controls
// still hold references only. Short runs only (each test well under 10 s), no wall-clock assertion.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class MoleculeLibraryUITests: XCTestCase {
    /// The view size in points of every drawn test.
    private let size = CGSize(width: 240, height: 160)

    func testEveryLibraryEntrysWords() {
        let expected: [(id: String, words: [String])] = [
            ("water", ["Water — H2O", "3 atoms, 2 bonds",
                       "Source: PubChem Compound CID 962, 3D conformer — public domain"]),
            ("methane", ["Methane — CH4", "5 atoms, 4 bonds",
                         "Source: PubChem Compound CID 297, 3D conformer — public domain"]),
            ("ethanol", ["Ethanol — C2H6O", "9 atoms, 8 bonds",
                         "Source: PubChem Compound CID 702, 3D conformer — public domain"]),
            ("benzene", ["Benzene — C6H6", "12 atoms, 12 bonds",
                         "Source: PubChem Compound CID 241, 3D conformer — public domain"]),
            ("caffeine", ["Caffeine — C8H10N4O2", "24 atoms, 25 bonds",
                          "Source: PubChem Compound CID 2519, 3D conformer — public domain"]),
        ]
        XCTAssertEqual(MoleculeCore.library.count, expected.count)
        for index in expected.indices {
            let molecule = MoleculeCore.library[index]
            XCTAssertEqual(molecule.id, expected[index].id)
            XCTAssertEqual(MoleculeControls.libraryWords(index: index), expected[index].words, molecule.id)
            // The source words come from the molecule's source record.
            let cid = MoleculeLibrary.pubChemCID(id: molecule.id) ?? -1
            XCTAssertEqual(molecule.source.title, "PubChem Compound CID \(cid), 3D conformer")
            XCTAssertEqual(molecule.source.license, "public-domain")
            XCTAssertEqual(MoleculePresenter.libraryIndex(id: molecule.id), index)
        }
        XCTAssertEqual(MoleculeControls.libraryWords(index: 5), [], "nothing outside the library")
        XCTAssertNil(MoleculePresenter.libraryIndex(id: "argon"))
    }

    func testChoosingALibraryEntrySelectsItAsTheMoleculeMenuDoes() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        let presenter = shell.presenter
        for index in [3, 0, 4] {
            // The Library button and the Molecule menu both send `molecule.select [index]` through the presenter.
            XCTAssertTrue(presenter.send("molecule.select", [Double(index)], through: shell.port).isAccepted)
            try MoleculeTest.frames(session, 1)
            XCTAssertEqual(try MoleculeTest.core(shell).selection, index)
            XCTAssertEqual(presenter.mirror.nameLine, MoleculeControls.libraryWords(index: index)[0])
        }
        XCTAssertTrue(presenter.nativeActions.contains("molecule.select"))
        session.close()
    }

    func testTheRecentMenuListsNewestFirst() async throws {
        XCTAssertEqual(MoleculeControls.recentValue([]), "No recent molecules")
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.mirror.recentIDs, ["water"], "the first molecule counts as opened")
        for index in [4, 2, 4] {
            XCTAssertTrue(presenter.send("molecule.select", [Double(index)], through: shell.port).isAccepted)
            try MoleculeTest.frames(session, 1)
        }
        XCTAssertEqual(presenter.mirror.recentIDs, ["caffeine", "ethanol", "water"], "unique, newest first")
        XCTAssertEqual(presenter.mirror.recentTitles, ["Caffeine", "Ethanol", "Water"])
        XCTAssertEqual(MoleculeControls.recentValue(presenter.mirror.recentTitles), "Caffeine, Ethanol, Water")
        // Choosing a recent entry sends `molecule.select` with its library index.
        let ethanol = try XCTUnwrap(MoleculePresenter.libraryIndex(id: "ethanol"))
        XCTAssertTrue(presenter.send("molecule.select", [Double(ethanol)], through: shell.port).isAccepted)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(try MoleculeTest.core(shell).selection, ethanol)
        XCTAssertEqual(presenter.mirror.recentTitles, ["Ethanol", "Caffeine", "Water"])
        session.close()
    }

    func testTheLabelsPickerChangesTheOverlaysLabelCount() async throws {
        XCTAssertEqual(LabelMode.allCases.map(MoleculePresenter.labelTitle), ["All", "Selected", "None"])
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size,
                                                presenter: TemporaryMoleculeStorage.presenter(nil))
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        try MoleculeTest.frames(session, 1)
        let all = presenter.mirror.labels.count
        XCTAssertGreaterThan(all, 1, "caffeine shows several labels")
        let digest = try moleculeDigest(try MoleculeTest.core(shell))
        let revision = shell.port.revision

        presenter.setLabelMode(.none)
        XCTAssertEqual(presenter.mirror.labelMode, .none)
        XCTAssertEqual(presenter.mirror.labels.count, 0, "None shows no label at once")
        presenter.setLabelMode(.selected)
        XCTAssertEqual(presenter.mirror.labels.count, 0, "Selected with nothing selected shows no label")
        XCTAssertEqual(shell.port.revision, revision, "nothing was sent")
        XCTAssertEqual(try moleculeDigest(try MoleculeTest.core(shell)), digest, "the picker is not an engine action")
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(presenter.mirror.labels.count, 0)

        XCTAssertTrue(shell.handle(control: "atom.select", values: [5]).isAccepted)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(presenter.mirror.labels.map(\.index), [5], "only the selected atom's label")
        XCTAssertNotNil(presenter.mirror.ring, "the ring is drawn in every mode")
        presenter.setLabelMode(.none)
        XCTAssertEqual(presenter.mirror.labels.count, 0)
        XCTAssertNotNil(presenter.mirror.ring)
        presenter.setLabelMode(.all)
        XCTAssertGreaterThan(presenter.mirror.labels.count, 1)
        XCTAssertEqual(presenter.mirror.labels.first?.index, 5, "the selected atom first")
        XCTAssertEqual(presenter.mirror.labels, presenter.lastLabels)
        XCTAssertFalse(presenter.nativeActions.contains("labels"), "not an engine action")
        session.close()
    }

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
        // The stores the Recent menu and the Labels picker reach through the presenter are references too.
        XCTAssertEqual(Mirror(reflecting: shell.presenter.recentStore).displayStyle, .class)
        XCTAssertEqual(Mirror(reflecting: shell.presenter.settingsStore).displayStyle, .class)
        session.close()
    }
}
