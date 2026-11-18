// LibraryTests — feature 162 (A22-P04) T-A22-409 (FR-A22-405, FR-A22-406; SC-A22-403; contracts/limits.md "Library").
// The named projects over a temporary storage (its own folder and defaults suite, removed after): save, open, rename
// and remove round trips keep the source, the values and the texture choices exactly; the 24-project cap (unreadable
// files count), the 1…40 character names and the case-insensitive duplicate names refuse with their messages and
// leave the storage byte-identical; damaged, newer-version, oversized, out-of-range and refused-project files are
// listed with their codes, refused on open and rename, kept on disk, and removable by an explicit call; a full byte
// quota (a filler file) refuses a save and a rename and keeps the previous file; the order is newest first, then the
// unreadable files; a project whose source the validator refuses saves as text; a newer index makes the library read
// only. Synthetic names only; short runs, no clock.
// Feature 162 T-A22-410 adds the presenter's side (`PresenterLibraryTests`): opening a saved project through the one
// app's session host lists its uniforms in the inspector with all its values (from feature 163 also past the selected
// template's uniform count); opening a project whose source is now
// refused shows its refusal and guidance while the preview keeps the last good shader; without storage the library
// is unavailable.
import CoreGraphics
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// A temporary storage of the experience: its own folder and defaults suite.
@MainActor
struct StudioStoragePlace {
    /// The defaults suite and folder name.
    let suite: String
    /// The root folder.
    let root: URL
    /// The handle.
    let storage: ExperienceStorage

    /// A fresh place named `name`.
    init(_ name: String) throws {
        suite = "a22.library-tests." + name
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let defaults = try #require(UserDefaults(suiteName: suite))
        storage = ExperienceStorage(id: StudioTest.id, root: root, defaults: defaults)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    /// Every file of the storage with its bytes.
    func contents() throws -> [String: Data] {
        var files: [String: Data] = [:]
        for name in storage.list() { files[name] = try storage.read(name) }
        return files
    }
}

/// Library helpers.
@MainActor
enum StudioLibraryTest {
    /// The Gradient template's project (uniform `u_speed`).
    static func project() throws -> ShaderProject {
        try #require(ShaderTemplates.all.first).project
    }

    /// The Gradient project with `source` instead of its own.
    static func project(source: String) throws -> ShaderProject {
        let base = try project()
        return try ShaderProject(name: base.name, source: source, uniforms: base.uniforms, limits: base.limits,
                                 textureInputs: base.textureInputs)
    }

    /// Sixteen distinct normalized values.
    static let values: [Double] = (0..<16).map { Double($0) / 16 + 0.03125 }
    /// Texture choices other than the defaults.
    static let textures = [TextureRecipe.noise.rawValue, TextureRecipe.checker.rawValue]

    /// The saved entry of `result`, recording an issue for a failure.
    static func saved(_ result: Result<ProjectLibraryEntry, ProjectLibraryFailure>,
                      sourceLocation: SourceLocation = #_sourceLocation) -> ProjectLibraryEntry? {
        switch result {
        case .success(let entry): return entry
        case .failure(let failure):
            Issue.record("refused: \(failure.code)", sourceLocation: sourceLocation)
            return nil
        }
    }

    /// The failure of `result`; nil for a success.
    static func failure<T>(_ result: Result<T, ProjectLibraryFailure>) -> ProjectLibraryFailure? {
        if case .failure(let failure) = result { return failure }
        return nil
    }

    /// Saves `name` with the Gradient project and the test values and textures.
    @discardableResult
    static func save(_ library: ProjectLibrary, _ name: String) throws
        -> Result<ProjectLibraryEntry, ProjectLibraryFailure> {
        library.save(name: name, project: try project(), values: values, textures: textures)
    }
}

@MainActor
@Suite(.serialized) struct LibraryTests {
    @Test func saveOpenRenameAndRemoveRoundTrip() throws {
        let place = try StudioStoragePlace("round-trip")
        defer { place.remove() }
        let library = ProjectLibrary(storage: place.storage)
        #expect(library.entries.isEmpty && library.next == 1 && !library.isReadOnly)
        let project = try StudioLibraryTest.project()
        let entry = try #require(StudioLibraryTest.saved(try StudioLibraryTest.save(library, "  Waves ")))
        #expect(entry.file == "project-1.json" && entry.name == "Waves" && entry.order == 1 && entry.isReadable)
        #expect(place.storage.exists(ProjectLibrary.indexFile))
        guard case .success(let opened) = library.open(entry.file) else {
            Issue.record("open refused")
            return
        }
        #expect(opened.project == project && opened.project.source == project.source)
        #expect(opened.values == StudioLibraryTest.values && opened.textures == StudioLibraryTest.textures)
        // A second library over the same storage reads the same list and counter.
        let again = ProjectLibrary(storage: place.storage)
        #expect(again.entries == library.entries && again.next == 2)
        let renamed = try #require(StudioLibraryTest.saved(library.rename(entry.file, to: "Ripples")))
        #expect(renamed.file == entry.file && renamed.order == entry.order && renamed.name == "Ripples")
        guard case .success(let reopened) = library.open(entry.file) else {
            Issue.record("open after rename refused")
            return
        }
        #expect(reopened.project == project && reopened.values == opened.values && reopened.textures == opened.textures)
        #expect(StudioLibraryTest.failure(library.remove(entry.file)) == nil)
        #expect(library.entries.isEmpty && !place.storage.exists(entry.file))
        #expect(StudioLibraryTest.failure(library.remove(entry.file)) == .notFound)
        // The counter is not reused after a removal.
        #expect(StudioLibraryTest.saved(try StudioLibraryTest.save(library, "Tide"))?.file == "project-2.json")
    }

    @Test func everyCapRefusesWithItsMessageAndChangesNothing() throws {
        let place = try StudioStoragePlace("caps")
        defer { place.remove() }
        let storage = place.storage
        // An unreadable file counts towards the 24.
        try storage.write(Data("{\"kind\":\"a22.saved-project\"".utf8), to: "project-1.json")
        let library = ProjectLibrary(storage: storage)
        for index in 1..<ProjectLibrary.maxProjects {
            _ = StudioLibraryTest.saved(try StudioLibraryTest.save(library, "Project \(index)"))
        }
        #expect(library.entries.count == 24 && library.readable.count == 23)
        var before = try place.contents()
        let full = StudioLibraryTest.failure(try StudioLibraryTest.save(library, "One more"))
        #expect(full == .full && full?.message == "The library holds 24 projects.")
        #expect(try place.contents() == before)
        // Names: trimmed, 1…40 characters, the same name regardless of case.
        #expect(StudioLibraryTest.failure(library.remove("project-24.json")) == nil)
        before = try place.contents()
        let target = try #require(library.entry(named: "Project 1"))
        for bad in ["", "   ", String(repeating: "b", count: 41)] {
            let refused = StudioLibraryTest.failure(try StudioLibraryTest.save(library, bad))
            #expect(refused == .invalidName && refused?.message == "A name has 1 to 40 characters.")
            #expect(StudioLibraryTest.failure(library.rename(target.file, to: bad)) == .invalidName)
        }
        let taken = StudioLibraryTest.failure(try StudioLibraryTest.save(library, "  project 2"))
        #expect(taken == .nameTaken("Project 2") && taken?.message == "A project is already called Project 2.")
        #expect(StudioLibraryTest.failure(library.rename(target.file, to: "PROJECT 3")) == .nameTaken("Project 3"))
        // Values and textures of the wrong count or range.
        let project = try StudioLibraryTest.project()
        let shortValues = library.save(name: "Short", project: project, values: [0.5],
                                       textures: StudioLibraryTest.textures)
        #expect(StudioLibraryTest.failure(shortValues) == .invalidState("values"))
        let badTexture = library.save(name: "Bad", project: project, values: StudioLibraryTest.values, textures: [0, 9])
        #expect(StudioLibraryTest.failure(badTexture) == .invalidState("textures"))
        #expect(try place.contents() == before)
        // A 40-character name and a rename to the same name in another case are accepted.
        let forty = String(repeating: "a", count: 40)
        #expect(StudioLibraryTest.saved(try StudioLibraryTest.save(library, forty))?.name == forty)
        #expect(StudioLibraryTest.saved(library.rename(target.file, to: "PROJECT 1"))?.name == "PROJECT 1")
    }

    @Test func unreadableFilesAreListedKeptAndOnlyRemovedOnRequest() throws {
        let place = try StudioStoragePlace("unreadable")
        defer { place.remove() }
        let storage = place.storage
        let project = try StudioLibraryTest.project()
        let good = try ProjectLibrary.encode(name: "Good", order: 1, project: project,
                                             values: StudioLibraryTest.values, textures: StudioLibraryTest.textures)
        let text = try #require(String(data: good, encoding: .utf8))
        try storage.write(Data("{\"kind\":\"a22.saved-project\"".utf8), to: "project-1.json")
        try storage.write(Data("{\"body\":{},\"kind\":\"a22.saved-project\",\"version\":2}".utf8), to: "project-2.json")
        try storage.write(good + Data(repeating: 0x20, count: ProjectLibrary.maxFileBytes), to: "project-3.json")
        let outOfRange = try ProjectLibrary.encode(name: "Wide", order: 2, project: project,
                                                   values: [Double](repeating: 2, count: 16),
                                                   textures: StudioLibraryTest.textures)
        try storage.write(outOfRange, to: "project-4.json")
        let nan = text.replacingOccurrences(of: #""defaultValue":[0-9.eE+-]+"#, with: "\"defaultValue\":\"NaN\"",
                                            options: .regularExpression)
        #expect(nan != text)
        try storage.write(Data(nan.utf8), to: "project-5.json")
        let before = try place.contents()
        let library = ProjectLibrary(storage: storage)
        #expect(library.entries.map { $0.refusal ?? "readable" }
                == ["damaged", "newer-version", "too-large", "out-of-range", "not-finite"])
        for entry in library.entries {
            let code = entry.refusal ?? ""
            #expect(StudioLibraryTest.failure(library.open(entry.file)) == .unreadable(code), "\(entry.file)")
            #expect(StudioLibraryTest.failure(library.rename(entry.file, to: "Fixed")) == .unreadable(code))
        }
        #expect(try place.contents() == before)
        #expect(ProjectLibrary(storage: storage).entries == library.entries)
        // A good project still saves after the highest file; the unreadable files stay; one is removed on request.
        let saved = try #require(StudioLibraryTest.saved(try StudioLibraryTest.save(library, "Waves")))
        #expect(saved.file == "project-6.json" && library.entries.first == saved)
        for (name, data) in before { #expect(try storage.read(name) == data, "\(name) kept") }
        #expect(StudioLibraryTest.failure(library.remove("project-1.json")) == nil)
        #expect(!storage.exists("project-1.json") && library.entries.count == 5)
    }

    @Test func aFullQuotaRefusesAndKeepsThePreviousFile() throws {
        let place = try StudioStoragePlace("quota")
        defer { place.remove() }
        let storage = place.storage
        let library = ProjectLibrary(storage: storage)
        let entry = try #require(StudioLibraryTest.saved(try StudioLibraryTest.save(library, "Waves")))
        let previous = try storage.read(entry.file)
        let used = try place.contents().values.reduce(0) { $0 + $1.count }
        try storage.write(Data(count: StorageQuota.maxBytes - used - 8), to: "filler.bin")
        let refused = StudioLibraryTest.failure(try StudioLibraryTest.save(library, "Ripples"))
        #expect(refused == .storage("storage.quota-exceeded"))
        #expect(refused?.message == "The library could not be changed (storage.quota-exceeded).")
        #expect(!storage.exists("project-2.json"))
        let longer = StudioLibraryTest.failure(library.rename(entry.file, to: "Waves at the end of a long day"))
        #expect(longer == .storage("storage.quota-exceeded"))
        #expect(try storage.read(entry.file) == previous && library.entries == [entry])
        guard case .success(let opened) = library.open(entry.file) else {
            Issue.record("open refused")
            return
        }
        #expect(opened.values == StudioLibraryTest.values)
    }

    @Test func theOrderIsNewestFirstThenUnreadableByNumber() throws {
        let place = try StudioStoragePlace("order")
        defer { place.remove() }
        let library = ProjectLibrary(storage: place.storage)
        let first = try #require(StudioLibraryTest.saved(try StudioLibraryTest.save(library, "Alpha")))
        _ = try StudioLibraryTest.save(library, "Beta")
        _ = try StudioLibraryTest.save(library, "Gamma")
        #expect(library.entries.map(\.name) == ["Gamma", "Beta", "Alpha"])
        // A rename keeps the order; unreadable files follow by number.
        _ = StudioLibraryTest.saved(library.rename(first.file, to: "Omega"))
        try place.storage.write(Data("not json".utf8), to: "project-9.json")
        try place.storage.write(Data("not json".utf8), to: "project-7.json")
        library.reload()
        #expect(library.entries.map(\.name) == ["Gamma", "Beta", "Omega", "project-7.json", "project-9.json"])
        #expect(library.next == 10)
    }

    @Test func aRefusedSourceSavesAsText() throws {
        let place = try StudioStoragePlace("refused-source")
        defer { place.remove() }
        let project = try StudioLibraryTest.project(source: StudioTest.refusedSource)
        #expect(!ShaderValidator.validate(project).isEmpty)
        let library = ProjectLibrary(storage: place.storage)
        let entry = try #require(StudioLibraryTest.saved(
            library.save(name: "Draft", project: project, values: StudioLibraryTest.values,
                         textures: StudioCore.defaultTextures)))
        guard case .success(let opened) = library.open(entry.file) else {
            Issue.record("open refused")
            return
        }
        #expect(opened.project.source == StudioTest.refusedSource && opened.textures == StudioCore.defaultTextures)
    }

    @Test func aNewerIndexMakesTheLibraryReadOnly() throws {
        let place = try StudioStoragePlace("newer-index")
        defer { place.remove() }
        let storage = place.storage
        let entry = try #require(StudioLibraryTest.saved(try StudioLibraryTest.save(ProjectLibrary(storage: storage),
                                                                                     "Waves")))
        try storage.write(Data("{\"body\":{},\"kind\":\"a22.project-library\",\"version\":2}".utf8),
                          to: ProjectLibrary.indexFile)
        let before = try place.contents()
        let library = ProjectLibrary(storage: storage)
        #expect(library.isReadOnly && library.indexProblem == "newer-version" && library.entries == [entry])
        #expect(StudioLibraryTest.failure(try StudioLibraryTest.save(library, "Tide")) == .readOnly)
        #expect(StudioLibraryTest.failure(library.rename(entry.file, to: "Tide")) == .readOnly)
        #expect(StudioLibraryTest.failure(library.remove(entry.file)) == .readOnly)
        #expect(StudioLibraryTest.failure(library.open(entry.file)) == nil)
        #expect(try place.contents() == before)
    }
}

/// The presenter's library (feature 162, T-A22-410), through the one app's session host.
@MainActor
@Suite(.serialized) struct PresenterLibraryTests {
    /// Opens Shader Studio in `session` with a library over `storage`, lays it out at 32 × 24 points and draws one
    /// frame.
    static func open(_ session: ExperienceSession, storage: ExperienceStorage) async throws
        -> ExperienceShell<StudioPresenter> {
        let id = StudioTest.id
        var made: ExperienceShell<StudioPresenter>?
        session.qualityPin = 0
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = ShaderStudioExperience.make(id: id, storage: Optional(storage))
            made = shell
            return shell
        }
        #expect(await session.open(request) == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 32, height: 24)
        view.layoutIfNeeded()
        try StudioTest.draw(session)
        return try #require(made)
    }

    @Test func openingListsTheOpenedUniformsWithTheirValues() async throws {
        let place = try StudioStoragePlace("presenter-open")
        defer { place.remove() }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Self.open(session, storage: place.storage)
        let presenter = shell.presenter
        #expect(presenter.library != nil)
        StudioTest.accept(shell, "template.select", [1])   // Noise flow: u_scale, u_speed
        StudioTest.accept(shell, "uniform.set", [0, 0.8])
        StudioTest.accept(shell, "uniform.set", [1, 0.6])
        try StudioTest.draw(session)
        let entry = try #require(StudioLibraryTest.saved(presenter.saveProject(name: "Flow")))
        let flow = ShaderTemplates.all[1]

        // Gradient has one uniform: since feature 163 the opened project's shape bounds the values, so both are kept.
        StudioTest.accept(shell, "template.select", [0])
        try StudioTest.draw(session)
        #expect(presenter.mirror.uniforms.map(\.name) == ["u_speed"])
        let compiles = presenter.pipeline.compileCount
        guard case .success(let opened) = presenter.openProject(entry.file) else {
            Issue.record("not opened")
            return
        }
        #expect(opened.project == flow.project)
        #expect(presenter.pipeline.compileCount == compiles, "opening compiles nothing in the control")
        #expect(presenter.mirror.source == flow.source)
        try StudioTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles + 1, "the queued run compiles at the frame")
        #expect(presenter.mirror.uniforms.map(\.name) == flow.uniforms.map(\.name), "the inspector lists them")
        #expect(try StudioTest.core(shell).values[0] == 0.8)
        #expect(try StudioTest.core(shell).values[1] == 0.6, "the value past Gradient's uniform is kept")
        #expect(try StudioTest.core(shell).shape == [2, 0])
        #expect(StudioInspector.rows(presenter.mirror).map(\.name) == ["u_scale", "u_speed"])
        #expect(presenter.mirror.status == "Compiled")
    }

    @Test func openingARefusedSourceShowsItsRefusalAndKeepsThePreview() async throws {
        let place = try StudioStoragePlace("presenter-refused")
        defer { place.remove() }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Self.open(session, storage: place.storage)
        let presenter = shell.presenter
        let library = try #require(presenter.library)
        let refused = try StudioLibraryTest.project(source: StudioTest.refusedSource)
        let entry = try #require(StudioLibraryTest.saved(library.save(name: "Old", project: refused,
                                                                       values: StudioCore.defaultValues(template: 0),
                                                                       textures: StudioCore.defaultTextures)))
        let before = try StudioTest.still(session)
        let live = presenter.pipeline.liveProject
        let results = presenter.apply(try #require(try? library.open(entry.file).get()))
        #expect(results.allSatisfy { $0 == .accepted }, "\(results)")
        try StudioTest.draw(session)
        #expect(presenter.mirror.source == StudioTest.refusedSource, "it opens in the editor")
        #expect(presenter.mirror.status == "Refused: version-line")
        #expect(presenter.mirror.guidance == Guidance.forIssue(.versionLine(1)))
        #expect(presenter.pipeline.liveProject == live)
        #expect(try StudioTest.still(session) == before, "the preview keeps the last good shader")
    }

    @Test func withoutStorageTheLibraryIsUnavailable() async throws {
        let shell = try await StudioTest.shell()
        #expect(shell.presenter.library == nil)
        #expect(StudioLibraryTest.failure(shell.presenter.saveProject(name: "Waves")) == .unavailable)
        #expect(StudioLibraryTest.failure(shell.presenter.openProject("project-1.json")) == .unavailable)
        #expect(StudioLibraryView.stacksButtons(.accessibility1) && !StudioLibraryView.stacksButtons(.large))
        let unreadable = ProjectLibraryEntry(file: "project-3.json", name: "project-3.json", order: 0,
                                             refusal: "damaged")
        #expect(StudioLibraryView.rowLabel(unreadable) == "project-3.json, unreadable: damaged")
    }
}
