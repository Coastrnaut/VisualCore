// AccessibilityTests — feature 148 (A20-P04) T-A20-403 (FR-A20-403; SC-A20-403; clarification Q3; contracts/library.md
// "Accessibility"; gap G-A11Y). Digital Zen Garden's accessibility without a system audit (audits wait for the device
// campaign, owner ruling of 2026-11-13), short runs only:
//   - every control's spoken label (`GardenControls.labels`) has a title and a value, the names are unique, and the
//     library, picture, undo and redo labels name their values ("Undo, a stroke", "Open Morning, Saved garden 1 of
//     2", "Unreadable garden …, damaged");
//   - the canvas description names the tone, the rake, the strokes, the stones and the selection;
//   - undo, redo, save, open, rename, delete, the picture and each refusal (a full garden, the stone cap, a used name)
//     are announced through the port, recorded by a recording sink in order;
//   - at the accessibility-five Dynamic Type size the controls, rendered with `ImageRenderer` at a proposed width of
//     390 points, are no wider than 390 points and taller than at the large size (the rows stack).
import Foundation
import SwiftUI
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreUI

@MainActor
@Suite(.serialized) struct AccessibilityTests {
    /// The width of the canvas the controls must fit, points.
    static let canvasWidth: CGFloat = 390

    @Test func everyControlHasASpokenLabelAndValue() async throws {
        let place = try GardenStoragePlace("a11y-labels")
        defer { place.remove() }
        let shell = try await GardenLibraryTest.shell(place.storage)
        let presenter = shell.presenter
        let mirror = presenter.mirror
        var labels = GardenControls.labels(mirror, entries: nil, name: "", stillReady: false)
        var byName = Dictionary(uniqueKeysWithValues: labels.map { ($0.name, $0.text) })
        #expect(byName["rake"] == "Rake, Fine rake" && byName["tone"] == "Sand tone, Pale sand")
        #expect(byName["undo"] == "Undo, nothing to undo" && byName["redo"] == "Redo, nothing to redo")
        #expect(byName["selection"] == "Selection, No stone selected")
        #expect(byName["still-make"] == "Make picture, PNG, 1600 by 1200 pixels" && byName["still-share"] == nil)
        #expect(byName["library-save"] == nil)

        GardenTest.rake(shell, from: Vec2(0.2, 0.3), to: Vec2(0.8, 0.4))
        GardenTest.accept(shell, "stone.place", [1, 0.4, 0.6])
        GardenTest.accept(shell, "stone.move", [0.5, 0.5])
        GardenTest.accept(shell, "edit.undo")
        _ = presenter.saveGarden(named: "Morning")
        _ = presenter.saveGarden(named: "Evening")
        try place.storage.write(Data("{".utf8), to: "garden-9.json")
        presenter.library?.reload()
        let entries = try #require(presenter.library?.entries)
        labels = GardenControls.labels(mirror, entries: entries, name: " Noon ", stillReady: true)
        #expect(Set(labels.map(\.name)).count == labels.count, "unique names")
        for label in labels {
            #expect(!label.title.isEmpty && !label.value.isEmpty, "\(label.name)")
            #expect(label.text == label.title + ", " + label.value, "\(label.name)")
        }
        byName = Dictionary(uniqueKeysWithValues: labels.map { ($0.name, $0.text) })
        #expect(byName["undo"] == "Undo, placing a stone" && byName["redo"] == "Redo, moving a stone")
        #expect(byName["selection"] == "Selection, Flat slate selected, 1 of 1, turned 0°")
        #expect(byName["stone-nudge-left"] == "Move left, Flat slate selected, 1 of 1, turned 0°")
        #expect(byName["library-name"] == "Garden name, Noon" && byName["library-save"] == "Save garden, Noon")
        #expect(byName["library-open-2"] == "Open Evening, Saved garden 1 of 2")
        #expect(byName["library-rename-1"] == "Rename Morning, Saved garden 2 of 2")
        #expect(byName["library-delete-1"] == "Delete Morning, Saved garden 2 of 2")
        #expect(byName["library-unreadable-9"] == "Unreadable garden garden-9.json, damaged")
        #expect(byName["library-delete-9"] == "Delete garden-9.json, unreadable, damaged")
        #expect(byName["still-share"] == "Share picture, PNG, 1600 by 1200 pixels")
        for (index, name) in StrokePatterns.names.enumerated() {
            #expect(byName["pattern-" + name] == GardenControls.patternLabel(index) + ", Fine rake")
        }
        // Every native action has a control with a label (the gesture actions included).
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions))
    }

    @Test func theDescriptionNamesToneStrokesStonesAndSelection() async throws {
        let shell = try await GardenTest.shell()
        let presenter = shell.presenter
        #expect(presenter.describe(try GardenTest.core(shell))
                == "Zen garden, Pale sand, Fine rake, 0 strokes, 0 stones, No stone selected")
        GardenTest.rake(shell, from: Vec2(0.2, 0.3), to: Vec2(0.8, 0.4))
        GardenTest.accept(shell, "sand.tone", [1])
        GardenTest.accept(shell, "rake.style", [1])
        GardenTest.accept(shell, "stone.place", [0, 0.4, 0.6])
        #expect(presenter.describe(try GardenTest.core(shell))
                == "Zen garden, Warm sand, Wide rake, 1 stroke, 1 stone, River pebble selected, 1 of 1, turned 0°")
        GardenTest.accept(shell, "stone.select", [0])
        #expect(shell.accessibilitySummary
                == "Zen garden, Warm sand, Wide rake, 1 stroke, 1 stone, No stone selected")
    }

    @Test func undoRedoLibraryPictureAndRefusalsAreAnnounced() async throws {
        let place = try GardenStoragePlace("a11y-announce")
        defer { place.remove() }
        let sink = RecordingAnnouncementSink()
        let shell = try await GardenLibraryTest.shell(place.storage, sink: sink)
        let presenter = shell.presenter
        let port = shell.port
        GardenTest.rake(shell, from: Vec2(0.2, 0.3), to: Vec2(0.8, 0.4))
        presenter.undo(port: port)
        presenter.redo(port: port)
        GardenTest.accept(shell, "stone.place", [1, 0.4, 0.6])
        GardenTest.accept(shell, "stone.move", [0.5, 0.5])
        presenter.undo(port: port)
        presenter.redo(port: port)
        presenter.undo(port: port)
        presenter.undo(port: port)
        GardenTest.accept(shell, "sand.tone", [2])
        presenter.undo(port: port)
        let entry = try #require(GardenLibraryTest.saved(presenter.saveGarden(named: "Morning")))
        _ = presenter.saveGarden(named: "Evening")
        _ = presenter.renameGarden(entry.file, to: "Evening")
        _ = presenter.renameGarden(entry.file, to: "Dawn")
        _ = presenter.openGarden(entry.file)
        _ = presenter.deleteGarden(entry.file)
        let failing = ExperienceStillRenderer { (_: Int, _: Int) throws(OffscreenRenderError) -> StillImage in
            throw OffscreenRenderError.unavailable("test")
        }
        presenter.makeStill(renderer: failing)
        #expect(sink.announced == [
            "Undid a stroke", "Redid a stroke", "Undid moving a stone", "Redid moving a stone",
            "Undid moving a stone", "Undid placing a stone", "Undid a sand tone change",
            "Saved Morning.", "Saved Evening.", "A garden is already called Evening.", "Renamed Morning to Dawn.",
            "Opened Dawn.", "Deleted Dawn.", "The picture could not be drawn.",
        ])
        // The opened garden has no history: a refused undo or redo announces nothing.
        let count = sink.announced.count
        presenter.redo(port: port)
        presenter.undo(port: port)
        #expect(sink.announced.count == count)
    }

    @Test func theStoneAndStrokeCapsAreAnnounced() async throws {
        let sink = RecordingAnnouncementSink()
        let shell = DigitalZenGardenExperience.make(id: GardenTest.id)
        shell.presenter.feedback = GardenLibraryTest.route(sink)
        try await shell.prepare(seed: 1)
        try shell.activate()
        let presenter = shell.presenter
        for index in 0..<GardenDocument.maxStones {
            GardenTest.accept(shell, "stone.place", [Double(index % 5), 0.5, 0.5])
        }
        let refused = presenter.placeStone(kind: 0, port: shell.port)
        #expect(refused.code == "action.rule." + GardenRule.stoneCap)
        #expect(presenter.mirror.message == GardenCore.stoneCapMessage)
        let full = presenter.restoreDocument?(dabGarden(GardenDocument.maxStrokes)) == true
        #expect(full)
        presenter.rakePattern(0, port: shell.port)
        #expect(sink.announced == [GardenCore.stoneCapMessage, GardenPresenter.fullMessage])
    }

    @Test func atAccessibilityFiveTheControlsStackWithinTheCanvas() async throws {
        let place = try GardenStoragePlace("a11y-layout")
        defer { place.remove() }
        let shell = try await GardenLibraryTest.shell(place.storage)
        let presenter = shell.presenter
        GardenTest.accept(shell, "stone.place", [1, 0.4, 0.6])
        _ = presenter.saveGarden(named: "Morning in the dry garden of the temple")
        _ = presenter.saveGarden(named: "Evening")
        presenter.mirror.stillURL = URL(fileURLWithPath: "/tmp/none.png")
        presenter.mirror.stillMessage = GardenPresenter.stillMadeMessage
        func rendered(_ size: DynamicTypeSize) throws -> CGImage {
            let controls = GardenControls(port: shell.port, mirror: presenter.mirror, presenter: presenter)
                .environment(\.dynamicTypeSize, size)
            let renderer = ImageRenderer(content: controls)
            renderer.proposedSize = ProposedViewSize(width: Self.canvasWidth, height: nil)
            renderer.scale = 1
            return try #require(renderer.cgImage)
        }
        let large = try rendered(.large)
        let largest = try rendered(.accessibility5)
        #expect(CGFloat(large.width) <= Self.canvasWidth, "width \(large.width) at large")
        #expect(CGFloat(largest.width) <= Self.canvasWidth, "width \(largest.width) at accessibility-five")
        #expect(largest.height > large.height, "the rows stack at accessibility-five")
    }
}
